require 'thor'
require 'dummy_log_generator'
require 'ext/hash/keys'
require 'ext/hash/except'

module DummyLogGenerator
  class CLI < Thor
    # options for serverengine
    class_option :pid_path, :aliases => ["-p"], :type => :string, :default => 'dummy_log_generator.pid'
    default_command :start

    def initialize(args = [], opts = [], config = {})
      super(args, opts, config)
    end

    desc "start", "Start a dummy_log_generator"
    option :config,    :aliases => ["-c"], :type => :string, :default => 'dummy_log_generator.conf', :desc => 'Config file'
    option :rate,      :aliases => ["-r"], :type => :numeric, :desc => 'Number of generating messages per second'
    option :output,    :aliases => ["-o"], :type => :string, :desc => 'Output file'
    option :message,   :aliases => ["-m"], :type => :string, :desc => 'Output message'
    # options for serverengine
    option :daemonize, :aliases => ["-d"], :type => :boolean, :desc => 'Daemonize. Stop with `dummy_log_generator stop`'
    option :workers,   :aliases => ["-w"], :type => :numeric, :desc => 'Number of parallels'
    option :worker_type,                   :type => :string, :default => 'process'
    def start
      @options = @options.dup # avoid frozen
      dsl =
        if options[:config] && File.exists?(options[:config])
          instance_eval(File.read(options[:config]), options[:config])
        else
          DummyLogGenerator::Dsl.new
        end
      @options[:setting] = dsl.setting
      dsl.setting.rate = options[:rate] if options[:rate]
      dsl.setting.output = options[:output] if options[:output]
      dsl.setting.message = options[:message] if options[:message]
      # options for serverengine
      @options[:workers] ||= dsl.setting.workers

      opts = @options.symbolize_keys.except(:config)
      se = ServerEngine.create(nil, DummyLogGenerator::Worker, opts)
      se.run
    end

    desc "stop", "Stops a dummy_log_generator"
    def stop
      pid = File.read(@options["pid_path"]).to_i

      begin
        Process.kill("QUIT", pid)
        puts "Stopped #{pid}"
      rescue Errno::ESRCH
        puts "DummyLogGenerator #{pid} not running"
      end
    end

    desc "graceful_stop", "Gracefully stops a dummy_log_generator"
    def graceful_stop
      pid = File.read(@options["pid_path"]).to_i

      begin
        Process.kill("TERM", pid)
        puts "Gracefully stopped #{pid}"
      rescue Errno::ESRCH
        puts "DummyLogGenerator #{pid} not running"
      end
    end

    desc "restart", "Restarts a dummy_log_generator"
    def restart
      pid = File.read(@options["pid_path"]).to_i

      begin
        Process.kill("HUP", pid)
        puts "Restarted #{pid}"
      rescue Errno::ESRCH
        puts "DummyLogGenerator #{pid} not running"
      end
    end

    desc "graceful_restart", "Graceful restarts a dummy_log_generator"
    def graceful_restart
      pid = File.read(@options["pid_path"]).to_i

      begin
        Process.kill("USR1", pid)
        puts "Gracefully restarted #{pid}"
      rescue Errno::ESRCH
        puts "DummyLogGenerator #{pid} not running"
      end
    end

  end
end

DummyLogGenerator::CLI.start(ARGV)
