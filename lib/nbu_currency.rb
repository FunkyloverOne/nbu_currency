require 'nbu_currency/version'
require 'open-uri'
require 'nokogiri'
require 'money'

class InvalidCache < StandardError ; end

class NbuCurrency < Money::Bank::VariableExchange

  attr_accessor :last_updated
  attr_accessor :rates_updated_at

  CURRENCIES = %w(USD CAD EUR GBP UAH).map(&:freeze).freeze
  NBU_RATES_URL = 'https://privat24.privatbank.ua/p24/accountorder?oper=prp&PUREXML&apicour&country=ua&full'.freeze

  def update_rates(cache=nil)
    update_parsed_rates(doc(cache))
  end

  def save_rates(cache, url=NBU_RATES_URL)
    raise InvalidCache unless cache
    File.open(cache, "w") do |file|
      io = open(url);
      io.each_line { |line| file.puts line }
    end
  end

  def update_rates_from_s(content)
    update_parsed_rates(doc_from_s(content))
  end

  def save_rates_to_s(url=NBU_RATES_URL)
    open(url).read
  end

  def exchange(cents, from_currency, to_currency)
    exchange_with(Money.new(cents, from_currency), to_currency)
  end

  def exchange_with(from, to_currency)
    from_base_rate, to_base_rate = nil, nil
    rate = get_rate(from, to_currency)

    unless rate
      @mutex.synchronize do
        opts = { without_mutex: true }
        from_base_rate = get_rate("UAH", from.currency.to_s, opts)
        to_base_rate = get_rate("UAH", to_currency, opts)
      end
      rate = to_base_rate / from_base_rate
    end

    calculate_exchange(from, to_currency, rate)
  end

  def get_rate(from, to, opts = {})
    fn = -> { @rates[rate_key_for(from, to, opts)] }

    if opts[:without_mutex]
      fn.call
    else
      @mutex.synchronize { fn.call }
    end
  end

  def set_rate(from, to, rate, opts = {})
    fn = -> { @rates[rate_key_for(from, to, opts)] = rate }

    if opts[:without_mutex]
      fn.call
    else
      @mutex.synchronize { fn.call }
    end
  end

  protected

  def doc(cache, url=NBU_RATES_URL)
    rates_source = !!cache ? cache : url
    Nokogiri::XML(open(rates_source)).tap { |doc| doc.xpath('exchangerate/exchangerate') }
  rescue Nokogiri::XML::XPath::SyntaxError
    Nokogiri::XML(open(url))
  end

  def doc_from_s(content)
    Nokogiri::XML(content)
  end

  def update_parsed_rates(doc)
    rates = doc.xpath('exchangerate/exchangerate')

    @mutex.synchronize do
      rates.each do |exchange_rate|
        rate = BigDecimal(exchange_rate.attribute("buy").value.to_i) / exchange_rate.attribute("unit").value.to_f / 10000.0
        currency = exchange_rate.attribute("ccy").value
        set_rate("UAH", currency, rate, :without_mutex => true)
      end
      set_rate("UAH", "UAH", 1, :without_mutex => true)
    end

    rates_updated_at = doc.xpath('exchangerate/exchangerate/@date').first.value
    @rates_updated_at = Time.parse(rates_updated_at)

    @last_updated = Time.now
  end

  private

  def calculate_exchange(from, to_currency, rate)
    to_currency_money = Money::Currency.wrap(to_currency).subunit_to_unit
    from_currency_money = from.currency.subunit_to_unit
    decimal_money = BigDecimal(to_currency_money) / BigDecimal(from_currency_money)
    money = (decimal_money * from.cents * rate).round
    Money.new(money, to_currency)
  end

  def rate_key_for(from, to, opts)
    key = "#{from}_TO_#{to}"
    key.upcase
  end
end
