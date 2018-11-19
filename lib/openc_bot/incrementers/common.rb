module OpencBot
  class NumericIncrementer < OpencBot::BaseIncrementer
    def initialize(name, opts = {})
      raise "You must specify an end_val for a NumericIncrementer" unless opts[:end_val]

      @start_val = opts[:start_val] || 0
      @end_val = opts[:end_val]
      super(name, opts)
    end

    def increment_yielder
      @expected_count = @end_val
      i = @start_val
      loop do
        raise StopIteration if i > @end_val

        yield i
        i += 1
      end
    end
  end

  class AsciiIncrementer < OpencBot::BaseIncrementer
    def initialize(name, opts = {})
      @size = opts[:size] || 3
      super(name, opts)
    end

    def increment_yielder
      alnum = (0...36).map { |i| i.to_s 36 } # 0...z
      all_perms = alnum.repeated_permutation(@size)
      case @size
      when 1
        @expected_count = 36
      when 2
        @expected_count = 1296
      when 3
        @expected_count = 46_656
      when 4
        @expected_count = 1_679_616
      end
      all_perms.each do |perm|
        yield perm.join
      end
    end
  end
end
