class CommandRunner
  class << self
    def do_system(*args)
      require 'tempfile'
      Tempfile.open do |log|
        args << {} unless args.last.is_a? Hash
        args.last.merge!(
          out: log.fileno,
          err: log.fileno,
        )
        system *args
        rc = $?
        log.rewind

        result = OpenStruct.new(status: rc, log: log.read)
        result.define_singleton_method(:success?) do
          rc.success?
        end
        result
      end
    end

    def do_system!(*args)
      result = do_system *args

      unless result.status.success?
        raise CommandFailedException, result
      end

      result
    end
  end

  class CommandFailedException < Exception
    def initialize(result)
      @result = result
    end

    def to_s
      "Command failed, result=#{result.status}"
    end

    def message
      to_s
    end
  end
end
