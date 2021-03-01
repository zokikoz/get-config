# templates.rb
# Telnet commands templates for getting configuration from various network devices

# 'enable' and 'super' authorization types uses @options[:user] as first password
# and @options[:pswd] as privileged password
module Templates
  # Alcatel OmniStack LS
  def omnistack
    @connection['Prompt'] = /([#>] |word:)\z/n
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

  # Alcatel OmniSwitch
  def omniswitch
    host = Net::Telnet.new(@connection)
    host.login(@options[:user], @options[:pswd])
    res = host.cmd('show configuration snapshot')
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
    @connection['Prompt'] = /([#>]|word: )\z/n
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

  # Cisco EtherSwitch module
  def cisco_es
    @connection['Prompt'] = /[#>]\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /Username: \z/n)
    host.puts("service-module #{@options[:esif]} session")
    host.waitfor(/Open\n\z/n)
    host.puts('')
    host.cmd('enable')
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

  # HP username/password login
  def hp_user
    @connection['Prompt'] = />\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /Username:\z/n)
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
    @connection['Timeout'] = 20 # EX models can have long delay before CLI
    host = Net::Telnet.new(@connection)
    host.login(@options[:user], @options[:pswd])
    res = host.cmd('show config | display set | no-more')
    host.close
    res
  end

  # D-Link new cisco-like style CLI (15xx)
  def dlink_new
    @connection['Prompt'] = /#\z/n
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /Username:\z/n)
    host.cmd('terminal length 0')
    res = host.cmd('show running-config')
    host.close
    res.gsub(/\n\r/, "\n") # Converting odd <LF><CR> output to normal <LF> end of line
  end

  # D-Link old own style CLI (12xx/32xx/35xx)
  def dlink_old
    @connection['Prompt'] = /:.+#\s?\z/n
    @connection['Telnetmode'] = false
    host = Net::Telnet.new(@connection)
    host.login('Name' => @options[:user], 'Password' => @options[:pswd],
               'PasswordPrompt' => /[Pp]ass[Ww]ord:\s?\z/n, 'LoginPrompt' => /[Uu]ser[Nn]ame:\s?\z/n)
    host.cmd('disable clipaging')
    res = host.cmd('show config current_config')
    host.cmd('enable clipaging')
    host.close
    res.gsub(/\n\r/, "\n") # Converting odd <LF><CR> output to normal <LF> end of line
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

  # Riverstone
  def riverstone
    host = Net::Telnet.new(@connection)
    host.puts('')
    host.login('Name' => @options[:user], 'Password' => @options[:pswd], 'LoginPrompt' => /User: \z/n)
    host.cmd('cli set command completion off')
    host.cmd('cli set terminal rows 0')
    host.cmd('enable')
    res = host.cmd('show running-config')
    host.close
    res
  end
end
