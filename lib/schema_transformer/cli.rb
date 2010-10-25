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
        opts.banner = "Usage: #{File.basename($0)} [options] [action]"
        
        opts.on("-h", "--help", "Display this help message.") do
          puts help_message
          puts opts
          exit
        end

        opts.on("-v", "--verbose",
          "Verbose mode"
        ) { |value| options[:verbose] = true }
        
        opts.on("-s", "--stagger",
          "Number of seconds to wait inbetween each bulk insert. Default 0"
        ) { |value| options[:stagger] = value }
        
        opts.on("-V", "--version",
          "Display the schema_transformer version, and exit."
        ) do
          require File.expand_path("../version", __FILE__)
          puts "Schema Transformer v#{SchemaTransformer::VERSION}"
          exit
        end

      end
    end
    
    def parse_options!
      @options = {:action => nil}
      
      if args.empty?
        warn "Please specifiy an action to execute."
        warn help_message
        warn option_parser
        exit 1
      end
      
      option_parser.parse!(args)
      extract_environment_variables!
      
      options[:action] = args # ignore remaining
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
      @action = options[:action].first
      if @action == "analyze"
        SchemaTransformer::Analyze.run(options)
      else
        begin
          SchemaTransformer::Transform.run(options)
        rescue UsageError => e
          puts "Usage Error: #{e.message}"
          puts help_message
          puts option_parser
        end
      end
    end
    
    private
    def help_message
      "Available actions: analyze, generate, sync, switch"
    end
  end
  
end

