module OpencBot
  class NumericIncrementer < OpencBot::Incrementer
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
end


module OpencBot
  class AlphaNumericIncrementer < OpencBot::Incrementer

    def increment_yielder
      @expected_count = 46656
      alnum = (0...36).map{|i|i.to_s 36} # 0...z
      all_perms = alnum.repeated_permutation(3)
      all_perms.each do |perm|
        yield perm.join
      end
    end
  end
end
