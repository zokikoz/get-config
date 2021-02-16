#!/usr/bin/env ruby
# get-conf.rb
# Gets configurations of network devices via telnet session

require 'net-telnet'
require 'fileutils'
require 'yaml'

require './templates'

CONFIG = {
  archv_dir: 'archive', # Archive directory path
  pool_file: 'pool.yml', # Devices pool file name
  pswd_file: 'pswd.yml', # Passwords file name
  error_log: 'errors.log' # Errors log file
}.freeze

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

  # Setting group or default login from pswd.yml file if credentials is not set in pool.yml
  def self.set_login(options, passwords, **default)
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
  # set_login

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
    # Sanitizing filename (strip, gsub), setting downcase.
    # Set 'unnamed' if it's empty after all (via .presence)
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

# Script start

# Creating pool and passwords example files
unless File.exist?(CONFIG[:pool_file])
  puts "Creating example devices pool file (#{CONFIG[:pool_file]})"
  pool = [{ name: 'full-example', host: 'localhost', port: 23, type: 'example',
            user: 'cisco', pswd: 'cisco', logs: 'example.log' },
          { name: 'base-example', host: '127.0.0.1', type: 'cisco' }]
  File.open(CONFIG[:pool_file], 'w') { |f| f.write(pool.to_yaml) }
end
unless File.exist?(CONFIG[:pswd_file])
  puts "Creating example passwords file (#{CONFIG[:pswd_file]})"
  passwords = [{ user: 'default-user', pswd: 'default-password', type: 'default' },
               { user: 'root', pswd: 'amnesiac', type: %w[juniper juniper1] }]
  File.open(CONFIG[:pswd_file], 'w') { |f| f.write(passwords.to_yaml) }
end

# Creating an archive directory
FileUtils.mkdir_p(CONFIG[:archv_dir]) unless Dir.exist?(CONFIG[:archv_dir])

# Loading passwords and pool files
passwords = YAML.safe_load(File.read(CONFIG[:pswd_file]), [Symbol])
pool = YAML.safe_load(File.read(CONFIG[:pool_file]), [Symbol])

unless pool.nil? || passwords.nil?
  # Creating a working directory
  work_dir = "#{CONFIG[:archv_dir]}/#{Time.now.strftime('%Y-%m-%d')}" # Naming by date
  work_dir = "#{work_dir}-#{Time.now.to_i.to_s[-6..-1]}" if Dir.exist?(work_dir) # Adding timestamp if dir exists
  FileUtils.mkdir_p(work_dir)
  puts "Saving in \"#{work_dir}\""

  # Start logging
  File.open(CONFIG[:error_log], 'a') { |f| f.write "#{Time.now.strftime('%d.%m.%Y %H:%M')} Starting #{work_dir}\n" }

  # Polling network devices from pool
  progress = { i: 0, err: 0, done: 0, string: 'Polling devices pool:' }
  pool.each do |options|
    print "\r\e[K#{progress[:string]} #{progress[:done]}% (#{options[:name]})" # Progress bar
    NetDevice.set_login(options, passwords) unless options.key?(:user) && options.key?(:pswd) # Setting credentials
    device = NetDevice.new(options) # Creating net device object
    result = device.load_config # Getting config from device
    device.save_config(work_dir, result) # Saving config
    
    # Progress calculation
    progress[:i] += 1
    progress[:err] += 1 if result[0, 4] == '!ERR'
    progress[:done] = (progress[:i] / pool.length.to_f * 100).to_i
  end
  puts "\r\e[K#{progress[:string]} #{progress[:done]}% (done)"
  puts "Errors: #{progress[:err]}. Check #{CONFIG[:error_log]}." if progress[:err].positive?
end
