#
# class CliMiami::A
#
class CliMiami::A
  attr_reader :value

  # A.sk API method
  #
  # See documentation for CliMiami::S.ay
  # The same options are accepted, with the addition of
  #   :readline   - uses Readline instead of standard `gets`
  #   :type       - symbol specifying what type of data is requested from the user
  #   :validate   - hash of validation options
  #
  def self.sk question, options = {}, &block
    new question, options, &block
  end

private

  def initialize question, options
    options = CliMiami.get_options options

    # add description to question
    question << ' (' << options[:description] << ')'

    # display question
    CliMiami::S.ay question, options

    # request given type to user
    @value = request_type options

    # return response if no block is passed
    # rubocop:disable Style/GuardClause
    if block_given?
      yield @value
    else
      return @value
    end
    # rubocop:enable Style/GuardClause
  end

  # determine the expecting type, and request input form user
  #
  def request_type options
    send("request_#{options[:type]}", options)
  rescue
    CliMiami::S.ay I18n.t('cli_miami.errors.type', options)
  end

  # for most types, a simple validation check is all that is needed
  # if validation fails, we request the user to try again
  #
  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def request_until_valid options, allow_empty_string = false
    response = nil

    while response.nil?
      # get user input based on given file type
      response = if options[:type] == :file
        Readline.readline.chomp '/'
      else
        $stdin.gets.chomp
      end

      # for multiple entry type objects, we allow the user to justs press enter to finish adding entries
      break if allow_empty_string && response == ''

      # otherwise validate the user's input
      validation = CliMiami::Validation.new response, options
      if validation.valid?
        response = validation.value
      else
        response = nil
        CliMiami::S.ay validation.error, :cli_miami_fail
      end
    end

    response
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity
  alias_method :request_boolean, :request_until_valid
  alias_method :request_file, :request_until_valid
  alias_method :request_float, :request_until_valid
  alias_method :request_fixnum, :request_until_valid
  alias_method :request_string, :request_until_valid
  alias_method :request_symbol, :request_until_valid

  # rubocop:disable Metrics/MethodLength
  def request_array options
    array = []
    value_options = CliMiami.get_options(options[:value_options] || {})

    # build the array by prompting the user
    # until the array length is an acceptable length, keep prompting user for values
    while array.length < options[:max]
      response = request_until_valid value_options, true

      if response.empty?
        break if CliMiami::Validation.new(array, options).valid?
        redo
      else
        array << response
      end

      # update user
      CliMiami::S.ay array.to_sentence, :cli_miami_success
    end

    array
  end

  # rubocop:disable Metrics/AbcSize, Metrics/BlockNesting, Metrics/PerceivedComplexity
  def request_hash options
    hash = {}
    options[:keys] ||= []
    value_options = CliMiami.get_options(options[:value_options] || {})
    required_keys_set = false

    # build the hash by prompting the user
    # until the hash length of keys is an acceptable length, keep prompting user for values
    while hash.keys.length < options[:max]
      # if keys options is set, prompt for those values first
      if required_keys_set == false
        options[:keys].each do |key|
          hash[key.to_sym] = request_until_valid value_options

          # update user
          CliMiami::S.ay hash.to_s, :cli_miami_success
        end

        # set boolean so we know all required keys are set
        required_keys_set = true

        # end this loop to re-check the while condition to make sure the max wasn't reached from required keys
        #   e.g. setting { max: 2, keys: [:foo, :bar] }
        #   this prevents users from entering user-defined keys since the max will already be met
        next

      # then start prompting for keys and values
      else
        # request key
        user_key = request_until_valid value_options.merge(type: :symbol), true

        if user_key.empty?
          break if CliMiami::Validation.new(hash, options).valid?
          redo
        else
          # request value
          CliMiami::S.ay I18n.t('cli_miami.core.enter_value_for', key: user_key), :cli_miami_success
          hash[user_key] = request_until_valid value_options, true
        end
      end

      CliMiami::S.ay hash.to_s, :cli_miami_success
    end

    hash
  end
  # rubocop:enable Metrics/AbcSize, Metrics/BlockNesting, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def request_range options
    start_value = nil
    end_value = nil
    range_value_options = CliMiami.get_options type: :float

    # get start value
    until (Float(start_value) rescue nil)
      CliMiami::S.ay I18n.t('cli_miami.core.enter_start_value'), preset: :cli_miami_success, newline: false
      start_value = request_until_valid range_value_options
    end

    # get end value
    until (Float(end_value) rescue nil)
      CliMiami::S.ay I18n.t('cli_miami.core.enter_end_value'), preset: :cli_miami_success, newline: false
      end_value = request_until_valid range_value_options
    end

    # swap values if entered in reverse
    start_value, end_value = end_value, start_value if start_value > end_value

    # build range object
    range = Range.new start_value, end_value

    # if range is invalid, start over and request it again
    if CliMiami::Validation.new(range, options).valid?
      range
    else
      request_range options
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
