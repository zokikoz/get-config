#!/usr/bin/env ruby
# get-conf.rb
# Gets configurations of network devices via telnet session

# Settings
CONFIG = {
  archv_dir: 'archive', # Archive directory path
  pool_file: %w[pool.yml], # Devices pools file names
  pswd_file: 'pswd.yml', # Passwords file name
  error_log: 'errors.log' # Errors log file
}.freeze

require 'net-telnet'
require 'fileutils'
require 'yaml'

require './templates'

# Preparations
module Prep
  # Creating pool example file
  def self.pool_file
    return if File.exist?(CONFIG[:pool_file][0])

    puts "Creating example devices pool file (#{CONFIG[:pool_file][0]})"
    pool = [{ name: 'full-example', host: 'localhost', port: 23, type: 'example',
              user: 'root', pswd: 'amnesiac', logs: 'example.log' },
            { name: 'base-example', host: '127.0.0.1', type: 'juniper' }]
    File.open(CONFIG[:pool_file][0], 'w') { |f| f.write(pool.to_yaml) }
  end

  # Creating passwords example file
  def self.pswd_file
    return if File.exist?(CONFIG[:pswd_file])

    puts "Creating example passwords file (#{CONFIG[:pswd_file]})"
    passwords = [{ user: 'default-user', pswd: 'default-password', type: 'default' },
                 { user: 'cisco', pswd: 'cisco', type: %w[cisco-user cisco-enable] }]
    File.open(CONFIG[:pswd_file], 'w') { |f| f.write(passwords.to_yaml) }
  end

  # First run check
  def self.first_run_chk(pool, passwords)
    return unless pool[0][:type] == 'example' || passwords[0][:user] == 'default-user'

    puts 'Modify config files to get started'
    exit 0
  end

  # Creating a working directory
  def self.work_dir(pool_name)
    if @base_dir.nil?
      @base_dir = "#{CONFIG[:archv_dir]}/#{Time.now.strftime('%Y-%m-%d')}" # Naming by date
      @base_dir = "#{@base_dir}-#{Time.now.to_i.to_s[-6..-1]}" if Dir.exist?(@base_dir) # Adding timestamp if dir exists
      work_dir = @base_dir
    end
    work_dir = "#{@base_dir}/#{pool_name}" unless CONFIG[:pool_file].length == 1 # Subdir if multiple pools
    FileUtils.mkdir_p(work_dir)
    puts "Saving in \"#{work_dir}\""
    work_dir
  end

  # Setting group or default login from pswd.yml file if credentials is not set in pool.yml
  def self.login(options, passwords, **default)
    catch(:done) do
      passwords.each do |group|
        case group[:type]
        when 'default'
          default.merge!(group) # Saving default login
        when options[:type]
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
      options.safe_merge!(default) # Setting default login if not find any suitable type in pswd.yml
    end
  end
  # set_login method end
end
# Prep module end

# Returns the receiver if it's not empty, else nil. Modified .presence method from rails
class Object
  def presence
    self unless empty?
  end
end

# Adding to hash only new keys and values (don't change old)
class Hash
  def safe_merge!(from)
    merge!(from) { |_key, old_value| old_value }
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
    pswd: 'password'
  }.freeze

  def initialize(options)
    @options = DEFAULT.merge(options)
    # Generating connection hash for net-telnet module
    @connection = if @options.key?(:logs)
                    { 'Host' => @options[:host], 'Port' => @options[:port], 'Output_log' => @options[:logs] }
                  else
                    { 'Host' => @options[:host], 'Port' => @options[:port] }
                  end
  end

  # Mixin templates methods for various types of network devices
  include Templates

  # Getting gonfiguration by command line templates
  def load_config
    res = send(@options[:type]) # Using @options[:type] value as method name from templates module
    raise StandardError, 'Empty response' if res.nil?
    raise StandardError, "Short response: \"#{res.gsub(/[\t\n\v\f\r]/, ' ')}\"" if res.length < 100

    res
  rescue StandardError => e
    log = "#{Time.now.strftime('%d.%m.%Y %H:%M')} #{@options[:name]} (#{@options[:host]}) - #{e}\n"
    File.open(CONFIG[:error_log], 'a') { |f| f.write log }
    "!ERR #{e}"
  end

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

  # Saving configuration to file
  def save_config(work_dir, result)
    filename = gen_filename(work_dir)
    File.open("#{work_dir}/#{filename}.cfg", 'w') { |f| f.write result }
  end
end
# NetDevice class end

# Pool progress
class Progress
  def initialize(options)
    @bar = { i: 0.0, err: 0, done: 0 }
    @bar.merge!(options)
  end

  # Progress bar
  def bar(name)
    print "\r\e[KPolling devices in #{@bar[:pool]} #{@bar[:done]}% (#{name})"
    return unless @bar[:done] == 100

    puts
    puts "Errors: #{@bar[:err]}. Check #{CONFIG[:error_log]}." if @bar[:err].positive?
  end

  # Progress calculation
  def calc(result)
    @bar[:i] += 1
    @bar[:err] += 1 if result[0, 4] == '!ERR'
    @bar[:done] = (@bar[:i] / @bar[:length] * 100).to_i
  end
end

# Script start

# Creating pool and passwords example files if they not exist
Prep.pool_file
Prep.pswd_file

# Creating an archive directory
FileUtils.mkdir_p(CONFIG[:archv_dir]) unless Dir.exist?(CONFIG[:archv_dir])
# Loading passwords file
passwords = YAML.safe_load(File.read(CONFIG[:pswd_file]), [Symbol])

# Loading pools
CONFIG[:pool_file].each do |pool_file|
  next unless File.exist?(pool_file)

  # Loading pool file
  pool = YAML.safe_load(File.read(pool_file), [Symbol])
  # TODO: check pool and password files structure
  next if pool.nil? || passwords.nil?

  pool_name = pool_file[0...-4]
  Prep.first_run_chk(pool, passwords) # First run check
  work_dir = Prep.work_dir(pool_name) # Creating a working directory
  # Start logging
  File.open(CONFIG[:error_log], 'a') { |f| f.write "#{Time.now.strftime('%d.%m.%Y %H:%M')} Starting #{work_dir}\n" }
  # Polling network devices from pool
  progress = Progress.new(pool: pool_name, length: pool.length)
  pool.each do |options|
    progress.bar(options[:name]) # Progress bar
    Prep.login(options, passwords) unless options.key?(:user) && options.key?(:pswd) # Setting credentials
    device = NetDevice.new(options) # Creating net device object
    result = device.load_config # Getting config from device
    device.save_config(work_dir, result) # Saving config
    progress.calc(result) # Progress calculation
  end
  progress.bar('done')
end
