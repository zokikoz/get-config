#!/usr/bin/env ruby
# get-conf.rb
# Gets configurations of network devices via telnet session

require 'net-telnet'
require 'fileutils'
require 'yaml'

require_relative 'templates'

# Settings
SETUP = {
  archv_dir: 'archive', # Archive directory path
  pool_file: %w[pool.yml], # Device pool filename
  pswd_file: 'pswd.yml', # Passwords filename
  error_log: 'errors.log' # Errors logfile
}.freeze

File.open('config.yml', 'w') { |f| f.write(SETUP.to_yaml) } unless File.exist?('config.yml')
CONFIG = YAML.safe_load(File.read('config.yml'), [Symbol])

SILENT = %w[-s --silent].include?(ARGV[0]) ? true : false

# Preparations
module Prep
  class CheckError < StandardError
  end

  POOL = [{ name: 'full-example', host: 'localhost', port: 23, type: 'cisco_es',
            user: 'admin', pswd: 'admin', esif: 'gi2/0', logs: 'example.log' },
          { name: 'base-example', host: '127.0.0.1', type: 'juniper' }].freeze

  PASSWORDS = [{ user: 'default-user', pswd: 'default-password', type: 'default' },
               { user: 'cisco', pswd: 'cisco', type: %w[cisco_user cisco_enable] }].freeze

  class << self
    # Creating a sample pool file
    def pool_file
      return if File.exist?(CONFIG[:pool_file][0])

      puts "Creating example devices pool file (#{CONFIG[:pool_file][0]})"
      File.open(CONFIG[:pool_file][0], 'w') { |f| f.write(POOL.to_yaml) }
    end

    # Creating a sample passwords file
    def pswd_file
      return if File.exist?(CONFIG[:pswd_file])

      puts "Creating example passwords file (#{CONFIG[:pswd_file]})"
      File.open(CONFIG[:pswd_file], 'w') { |f| f.write(PASSWORDS.to_yaml) }
    end

    # Pool structure check
    def pool_struct_check(pool)
      pool.each do |pool_unit|
        raise CheckError, 'Wrong pool file structure' unless pool_unit.is_a?(Hash)
        raise CheckError, 'Wrong pool file structure' unless pool_unit.keys?(POOL[1])
      end
    end

    # Passwords structure check
    def pswd_struct_check(pswd)
      pswd.each do |pswd_unit|
        raise CheckError, 'Wrong passwords file structure' unless pswd_unit.is_a?(Hash)
        raise CheckError, 'Wrong passwords file structure' unless pswd_unit.keys?(PASSWORDS[1])
      end
    end

    # Pools and passwords files check
    def check(pool, passwords)
      raise CheckError, 'Empty config file' if pool.nil? || passwords.nil?
      raise CheckError, 'Modify config files to get started' if pool == POOL || passwords == PASSWORDS

      pool_struct_check(pool)
      pswd_struct_check(passwords)
    rescue CheckError => e
      log = "#{Time.now.strftime('%d.%m.%Y %H:%M')} #{e}\n"
      File.open(CONFIG[:error_log], 'a') { |f| f.write log }
      puts e
      exit 0
    end

    # Creating a working directory
    def work_dir(pool_name)
      if @base_dir.nil?
        @base_dir = "#{CONFIG[:archv_dir]}/#{Time.now.strftime('%Y-%m-%d')}" # Naming by date
        @base_dir = "#{@base_dir}-#{Time.now.to_i.to_s[-6..-1]}" if Dir.exist?(@base_dir) # Add timestamp if dir exists
        work_dir = @base_dir
      end
      work_dir = "#{@base_dir}/#{pool_name}" unless CONFIG[:pool_file].length == 1 # Subdir if multiple pools
      FileUtils.mkdir_p(work_dir)
      puts "Saving in \"#{work_dir}\"" unless SILENT
      work_dir
    end

    # Setting group or default login from pswd.yml file if credentials is not set in pool.yml
    def login(options, passwords, **default)
      catch(:done) do
        passwords.each do |group|
          case group[:type]
          when 'default'
            default.merge!(group) # Saving the default login
          when options[:type], options[:pgrp]
            options.safe_merge!(group)
            throw :done
          when Array
            group[:type].each do |type|
              if type == options[:type]
                options.safe_merge!(group)
                throw :done
              end
            end
          end
        end
        options.safe_merge!(default) # Setting the default login if not find any suitable type in pswd.yml
      end
    end
    # set_login method end
  end
  # << self methods end
end
# Prep module end

# Returns the receiver if it's not empty, else nil. Modified .presence method from rails
class Object
  def presence
    self unless empty?
  end
end

# Hash class new methods
class Hash
  # Adding to the hash only new keys and values (don't change old)
  def safe_merge!(from)
    merge!(from) { |_key, old_value| old_value }
  end

  # Comparing that the first hash contains all keys from the second hash
  def keys?(hash2)
    (hash2.keys - keys).empty?
  end
end

# Creating network device object using net-telnet module
class NetDevice
  DEFAULT = {
    name: 'localhost',
    host: 'localhost',
    port: 23,
    type: 'example',
    user: 'username',
    pswd: 'password',
    esif: 'gi2/0' # Cisco EtherSwitch interface
  }.freeze

  attr_reader :err

  def initialize(options)
    @options = DEFAULT.merge(options)
    @err = 0
    # Generating connection hash for net-telnet module
    @connection = if @options.key?(:logs)
                    { 'Host' => @options[:host], 'Port' => @options[:port], 'Output_log' => @options[:logs] }
                  else
                    { 'Host' => @options[:host], 'Port' => @options[:port] }
                  end
  end

  # Mixin templates methods for various types of network devices
  include Templates

  # Getting device gonfiguration by command line templates
  def load_config
    res = send(@options[:type]) # Using @options[:type] value as method name from templates module
    raise StandardError, 'Empty response' if res.nil?
    raise StandardError, "Short response: \"#{res.gsub(/[\t\n\v\f\r]/, ' ')}\"" if res.length < 100

    res
  rescue StandardError => e
    log = "#{Time.now.strftime('%d.%m.%Y %H:%M')} #{@options[:name]} (#{@options[:host]}) - #{e}\n"
    File.open(CONFIG[:error_log], 'a') { |f| f.write log }
    @err = 1
    e
  end

  # Saving device configuration to file
  def save_config(work_dir, result)
    filename = gen_filename(work_dir)
    File.open("#{work_dir}/#{filename}.cfg", 'w') { |f| f.write result }
  end

  private

  # Creating correct filename based on @options[:name]
  def gen_filename(work_dir)
    # Sanitizing filename (strip, gsub), setting downcase. Set 'unnamed' if it's empty after all (via .presence)
    filename = @options[:name].strip.gsub(/[^0-9A-Za-z_\-]/, '').downcase.presence || 'unnamed'
    namesakes = Dir.glob("#{work_dir}/#{filename}.*") # Checking for duplicate filenames
    unless namesakes.empty?
      namesakes.map! { |f| f[0...-4].split('.').last.to_i } # Getting numeric suffix from dup filenames
      filename = "#{filename}.#{namesakes.max + 1}" # Creating a new filename by increasing the maximum suffix
    end
    filename
  end
end
# NetDevice class end

# Pool polling progress
class Progress
  def initialize(options)
    @bar = { i: 0, err: 0, done: 0 }
    @bar.merge!(options)
  end

  # Progress bar
  def bar(name)
    return if SILENT

    print "\r\e[KPolling devices in #{@bar[:pool]}: #{@bar[:done]}% (#{@bar[:i]}/#{@bar[:length]}), #{name}"
    return unless @bar[:done] == 100

    puts
    puts "Errors: #{@bar[:err]}. Check #{CONFIG[:error_log]}." if @bar[:err].positive?
  end

  # Progress calculation
  def calc(err)
    @bar[:i] += 1
    @bar[:err] += err
    @bar[:done] = (@bar[:i].to_f / @bar[:length] * 100).to_i
  end
end

# Time measurement
class Chronometry
  def initialize
    @starting = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i
  end

  def stop
    ending = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i
    elapsed_sec = ending - @starting
    elapsed = elapsed_sec.divmod(60)
    log = "#{Time.now.strftime('%d.%m.%Y %H:%M')} Finished. Elapsed time: #{elapsed[0]}m #{elapsed[1]}s\n"
    File.open(CONFIG[:error_log], 'a') { |f| f.write log }
  end
end

# The script starts

# Creating pool and passwords sample files if they don't exist
Prep.pool_file
Prep.pswd_file

# Creating an archive directory
FileUtils.mkdir_p(CONFIG[:archv_dir]) unless Dir.exist?(CONFIG[:archv_dir])
# Loading a passwords file
passwords = YAML.safe_load(File.read(CONFIG[:pswd_file]), [Symbol])

stopwatch = Chronometry.new # Runtime measurement
# Loading pools
CONFIG[:pool_file].each do |pool_file|
  next unless File.exist?(pool_file)

  pool = YAML.safe_load(File.read(pool_file), [Symbol]) # Loading a pool file
  pool_name = pool_file[0...-4]
  Prep.check(pool, passwords) # Pool and passwords files check
  work_dir = Prep.work_dir(pool_name) # Creating a working directory
  # Starting logging
  File.open(CONFIG[:error_log], 'a') { |f| f.write "#{Time.now.strftime('%d.%m.%Y %H:%M')} Starting #{work_dir}\n" }
  # Polling network devices from a pool
  progress = Progress.new(pool: pool_name, length: pool.length)
  pool.each do |options|
    progress.bar(options[:name]) # Displaying a progress bar
    Prep.login(options, passwords) unless options.key?(:user) && options.key?(:pswd) # Setting credentials
    device = NetDevice.new(options) # Creating a net device object
    result = device.load_config # Getting config from the device
    device.save_config(work_dir, result) # Saving device config
    progress.calc(device.err) # Progress calculation
  end
  progress.bar('done.')
end
stopwatch.stop
