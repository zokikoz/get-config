# templates.rb
# Telnet commands templates for getting configuration from various network devices

# 'enable' and 'super' authorization types uses @options[:user] as first password
# and @options[:pswd] as privileged password
module Templates
  # Alcatel Omnistack LS
  def omnistack
    @connection['Prompt'] = /([#>] |:)\z/n
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password:\z/n)
    host.cmd(@options[:user])
    host.cmd('enable')
    host.cmd(@options[:pswd])
    host.cmd('terminal datadump')
    res = host.cmd('show running-config')
    host.close
    res
  end

  # Cisco username/password login
  def cisco_user
    @connection['Prompt'] = /#\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /Username: \z/n)
    host.cmd('terminal length 0')
    res = host.cmd('show running-config')
    host.close
    res
  end

  # Cisco enable password login
  def cisco_enable
    @connection['Prompt'] = /([#>]|: )\z/n
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password: \z/n)
    host.cmd(@options[:user])
    host.cmd('enable')
    host.cmd(@options[:pswd])
    host.cmd('terminal length 0')
    res = host.cmd('show running-config')
    host.close
    res
  end

  # Cisco ASA
  def cisco_asa
    @connection['Prompt'] = /([#>]|word:) \z/n
    @connection['Telnetmode'] = false
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password: \z/n)
    host.cmd(@options[:user])
    host.cmd('enable')
    host.cmd(@options[:pswd])
    host.cmd('terminal pager 0')
    res = host.cmd('show running-config')
    host.close
    res
  end

  # HP super password login
  def hp_super
    @connection['Prompt'] = /[>:]\z/n
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password:\z/n)
    host.cmd(@options[:user])
    host.cmd('super')
    host.cmd(@options[:pswd])
    host.cmd('screen-length disable')
    res = host.cmd('display current-configuration')
    host.close
    res
  end

  # HP no super password needed (user privilege 3)
  def hp_nosuper
    @connection['Prompt'] = /[>:]\z/n
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password:\z/n)
    host.cmd(@options[:pswd])
    host.cmd('screen-length disable')
    res = host.cmd('display current-configuration')
    host.close
    res
  end

  # H3C no super password
  def h3c_nosuper
    @connection['Prompt'] = /[>\]:]\z/n
    host = Net::Telnet.new(@connection)
    host.waitfor(/Password:\z/n)
    host.puts(@options[:pswd])
    host.waitfor(/login\z/n)
    host.cmd('system-view')
    host.cmd('user-interface vty 0 4')
    host.cmd('screen-length 0')
    res = host.cmd('display current-configuration')
    host.cmd('undo screen-length')
    host.close
    res
  end

  # Juniper
  def juniper
    host = Net::Telnet.new(@connection)
    host.login(@options[:user], @options[:pswd])
    res = host.cmd('show config | display set | no-more')
    host.close
    res
  end

  # D-Link 15xx
  def dlink_15xx
    @connection['Prompt'] = /#\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /Username:\z/n)
    host.cmd('terminal length 0')
    res = host.cmd('show running-config')
    host.close
    res.gsub!(/\n\r/, "\n") # Converting odd <LF><CR> output to normal <LF> end of line
  end

  # D-Link 12xx
  def dlink_12xx
    @connection['Prompt'] = /[:#] \z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /[Uu]ser[Nn]ame: \z/n)
    host.cmd('disable clipaging')
    res = host.cmd('show config current_config')
    host.cmd('enable clipaging')
    host.close
    res
  end

  # D-Link 35xx
  def dlink_35xx
    @connection['Prompt'] = /[:#]\z/n
    @connection['Telnetmode'] = false
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /username:\z/n)
    host.cmd('disable clipaging')
    res = host.cmd('show config current_config')
    host.cmd('enable clipaging')
    host.close
    res.gsub!(/\n\r/, "\n") # Converting odd <LF><CR> output to normal <LF> end of line
  end

  # Eltex
  def eltex
    @connection['Prompt'] = /#\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /User Name:\z/n)
    host.cmd('terminal datadump')
    res = host.cmd('show running-config')
    host.close
    res
  end

  # Extreme
  def extreme
    host = Net::Telnet.new(@connection)
    host.login(@options[:user], @options[:pswd])
    host.cmd('disable clipaging')
    res = host.cmd('show configuration')
    host.close
    res
  end
end
