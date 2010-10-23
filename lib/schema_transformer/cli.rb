#!/usr/bin/env ruby

require 'rubygems'
require 'active_wrapper'

module SchemaTransformer
  class CLI
    
    def self.run(args)
      cli = new(args)
      cli.parse_options!
      cli.run
    end
    
    # The array of (unparsed) command-line options
    attr_reader :args
    # The hash of (parsed) command-line options
    attr_reader :options
    
    def initialize(args)
      @args = args.dup
    end
    
    # Return an OptionParser instance that defines the acceptable command
    # line switches for cloud_info, and what their corresponding behaviors
    # are.
    def option_parser
      # @logger = Logger.new
      @option_parser ||= OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] action ..."
        
        opts.on("-h", "--help", "Display this help message.") do
          puts opts
          exit
        end

        opts.on("-V", "--version",
          "Display the schema_transformer version, and exit."
        ) do
          require 'schema_transformer/version'
          puts "Schema Transformer v#{SchemaTransformer::Version}"
          exit
        end

      end
    end
    
    def parse_options!
      @options = {:actions => []}
      
      if args.empty?
        warn "Please specifiy an action to execute."
        warn option_parser
        exit 1
      end
      
      option_parser.parse!(args)
      coerce_variable_types!
      extract_environment_variables!
      
      options[:actions].concat(args)
    end
    
    # Extracts name=value pairs from the remaining command-line arguments
    # and assigns them as environment variables.
    def extract_environment_variables! #:nodoc:
      args.delete_if do |arg|
        next unless arg.match(/^(\w+)=(.*)$/)
        ENV[$1] = $2
      end
    end

    def run
      puts "TODO FINISH LOGIC"
      pp options
    end
  end
  
end

