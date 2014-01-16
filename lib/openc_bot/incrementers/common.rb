module OpencBot
  class NumericIncrementer < OpencBot::BaseIncrementer
    def initialize(opts={})
      raise "You must specify an end_val for a NumericIncrementer" if ! opts[:end_val]
      @start_val = opts[:start_val] || 0
      @end_val = opts[:end_val]
      super(opts)
    end

    def increment_yielder
      @expected_count = @end_val
      i = @start_val
      loop do
        if i > @end_val
          raise StopIteration
        end
        yield i
        i += 1
      end
    end
  end

  class AsciiIncrementer < OpencBot::BaseIncrementer
    def initialize(opts={})
      @size = opts[:size] || 3
      super(opts)
    end

    def increment_yielder
      alnum = (10...36).map{|i|i.to_s 36} # 0...z
      all_perms = alnum.repeated_permutation(@size)
      case @size
      when 2
        @expected_count = 1296
      when 3
        @expected_count = 46656
      when 4
        @expected_count = 1679616
      end
      all_perms.each do |perm|
        yield perm.join
      end
    end
  end
end
