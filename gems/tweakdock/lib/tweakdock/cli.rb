module TweakDock
  class CLI
    USAGE = <<~TEXT.freeze
      Usage: tweakdock generate FILE...
             tweakdock check FILE...

      generate  Writes the Swift file of each experiments YAML file.
      check     Fails when a Swift file is not up to date. It changes no files.
    TEXT

    def self.start(arguments, out: $stdout, err: $stderr)
      new(out: out, err: err).run(arguments)
    end

    def initialize(out:, err:)
      @out = out
      @err = err
    end

    def run(arguments)
      command, *files = arguments
      case command
      when "generate", "check"
        return usage(2, "give at least one YAML file.") if files.empty?

        results = files.map { |file| process(command, file) }
        results.all? ? 0 : 1
      when "--version", "-v"
        @out.puts(VERSION)
        0
      when nil, "help", "--help", "-h"
        usage(0)
      else
        usage(2, "unknown command #{command}.")
      end
    end

    private

    def process(command, file)
      send(command, Spec.load(file))
    rescue Error, SystemCallError => e
      @err.puts("error: #{e.message}")
      false
    end

    def generate(spec)
      path = spec.output_path
      swift = Generator.new(spec).swift
      if up_to_date?(path, swift)
        @out.puts("#{path} is up to date.")
      else
        File.write(path, swift)
        @out.puts("Wrote #{path}.")
      end
      true
    end

    def check(spec)
      return true if up_to_date?(spec.output_path, Generator.new(spec).swift)

      @err.puts("error: #{spec.output_path} is not up to date. Run: tweakdock generate #{spec.path}")
      false
    end

    def up_to_date?(path, swift)
      File.exist?(path) && File.read(path) == swift
    end

    def usage(status, message = nil)
      stream = status.zero? ? @out : @err
      stream.puts("error: #{message}") if message
      stream.puts(USAGE)
      status
    end
  end
end
