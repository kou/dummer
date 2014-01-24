module Dummer
  class Generator
    def initialize(setting)
      @message_proc =
        if fields = setting.fields
          Field.message_proc(fields, setting.labeled, setting.delimiter)
        elsif input = setting.input
          Input.message_proc(input)
        else
          Message.message_proc(setting.message)
        end
    end

    def generate
      @message_proc.call
    end

    class Message
      def self.message_proc(message)
        message = "#{message.chomp}\n"
        Proc.new { message }
      end
    end

    class Input
      def self.message_proc(input)
        messages = nil
        begin
          open(input) do |in_file|
            messages = in_file.readlines
          end
        rescue Errno::ENOENT
          raise ConfigError.new("Input file `#{input}` is not readable")
        end
        idx = -1
        size = messages.size
        Proc.new {
          idx = (idx + 1) % size
          messages[idx]
        }
      end
    end

    class Field
      def self.message_proc(fields, labeled, delimiter)
        format_proc = format_proc(labeled, delimiter)
        field_procs = field_procs(fields)

        prev_data = {}
        Proc.new {
          data = {}
          field_procs.each do |key, proc|
            prev = prev_data[key] || -1
            data[key] = proc.call(prev)
          end
          prev_data = data
          format_proc.call(data)
        }
      end

      def self.format_proc(labeled, delimiter)
        if labeled
          Proc.new {|fields| "#{fields.map {|key, val| "#{key}:#{val}" }.join(delimiter)}\n" }
        else
          Proc.new {|fields| "#{fields.values.join(delimiter)}\n" }
        end
      end

      def self.field_procs(fields)
        rand = ::Dummer::Random.new
        field_procs = {}
        fields.each do |key, opts|
          opts = opts.dup
          type = opts.delete(:type)
          field_procs[key] =
            case type
            when :string
              rand.string(opts)
            when :integer
              rand.integer(opts)
            when :float
              rand.float(opts)
            when :datetime
              rand.datetime(opts)
            else
              raise ConfigError.new(type)
            end
        end
        field_procs
      end
    end
  end

  class Random
    def initialize
      @rand = ::Random.new(0)
      @chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a # no symbols and multi-bytes for now
    end

    def range(range)
      rand(range)
    end

    def any(any)
      any[rand(any.size-1)]
    end

    def rand(arg = nil)
      @rand.rand(arg)
    end

    # belows are data types

    def string(length: 8, any: nil, value: nil)
      if value
        string = value.to_s
        Proc.new { string }
      elsif any
        Proc.new { self.any(any) }
      else
        Proc.new { Array.new(length){@chars[rand(@chars.size-1)]}.join }
      end
    end

    def integer(format: nil, range: nil, countup: false, value: nil)
      if format
        if value
          integer = sprintf(format, value.to_i)
          Proc.new { integer }
        elsif range
          Proc.new { sprintf(format, self.range(range)) }
        elsif countup
          Proc.new {|prev| sprintf(format, prev.to_i + 1) }
        else
          Proc.new { sprintf(format, rand(0..2,147,483,647)) }
        end
      else
        if value
          integer = value.to_i
          Proc.new { integer }
        elsif range
          Proc.new { self.range(range) }
        elsif countup
          Proc.new {|prev| prev + 1 }
        else
          Proc.new { rand(0..2,147,483,647) }
        end
      end
    end

    def float(format: nil, range: nil, value: nil)
      if format
        if value
          float = value.to_f
          Proc.new { sprintf(format, float) }
        elsif range
          Proc.new { sprintf(format, self.range(range)) }
        else
          Proc.new { r = rand(1..358); sprintf(format, r * Math.cos(r)) }
        end
      else
        if value
          float = value.to_f
          Proc.new { float }
        elsif range
          Proc.new { self.range(range) }
        else
          Proc.new { r = rand(1..358); r * Math.cos(r) }
        end
      end
    end

    def datetime(format: "%Y-%m-%d %H:%M:%S.%3N", random: false, value: nil)
      if value
        Proc.new { value.strftime(format) }
      elsif random
        Proc.new {
          y = rand(1970..2037);
          m = rand(1..12);
          d = rand(1..27);
          h = rand(0..23);
          min = rand(0..59);
          s = rand(0..59);
          usec = rand(0..999999);
          Time.local(y, m, d, h, min, s, usec).strftime(format)
        }
      else
        Proc.new { Time.now.strftime(format) }
      end
    end
  end
end