module OpencBot

  # Generic Error class for OpencBot exceptions
  class OpencBotError < StandardError;end

  #
  # Raised by <tt>save_entity!</tt> when the record is invalid.
  # Use the +validation_errors+ method to retrieve the, er, validation errors.
  class RecordInvalid < OpencBotError
    attr_reader :validation_errors

    def initialize(validation_errors)
      @validation_errors = validation_errors
    end
  end

end