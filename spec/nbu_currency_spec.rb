require 'spec_helper'

describe NbuCurrency do
  before(:each) do
    @bank = NbuCurrency.new
    @dir_path = File.dirname(__FILE__)
    @cache_path = File.expand_path(@dir_path + '/exchange_rates.xml')
    @tmp_cache_path = File.expand_path(@dir_path + '/tmp/exchange_rates.xml')
    yml_cache_path = File.expand_path(@dir_path + '/exchange_rates.yml')
    @exchange_rates = YAML.load_file(yml_cache_path)
  end

  after(:each) do
    [@tmp_cache_path].each do |file_name|
      if File.exists? file_name
        File.delete file_name
      end
    end
  end

  it 'has a version number' do
    expect(NbuCurrency::VERSION).not_to be nil
  end

  it "should save the xml file from nbu given a file path" do
    @bank.save_rates(@tmp_cache_path)
    expect(File.exists?(@tmp_cache_path)).to eq(true)
  end

  it "should save the xml file from nbu given a file path and url" do
    @bank.save_rates(@tmp_cache_path, NbuCurrency::NBU_RATES_URL)
    expect(File.exists?(@tmp_cache_path)).to eq(true)
  end

  it "should raise an error if an invalid path is given to save_rates" do
    expect { @bank.save_rates(nil) }.to raise_exception(InvalidCache)
  end

  it "should update itself with exchange rates from nbu website" do
    allow(OpenURI::OpenRead).to receive(:open).with(NbuCurrency::NBU_RATES_URL) {@cache_path}
    @bank.update_rates
    NbuCurrency::CURRENCIES.each do |currency|
      expect(@bank.get_rate("UAH", currency)).to be > 0
    end
  end

  it "should update itself with exchange rates from nbu website when the data get from cache is illegal" do
    illegal_cache_path = File.expand_path(@dir_path + '/illegal_exchange_rates.xml')
    allow(OpenURI::OpenRead).to receive(:open).with(NbuCurrency::NBU_RATES_URL) {@cache_path}
    @bank.update_rates(illegal_cache_path)
    NbuCurrency::CURRENCIES.each do |currency|
      expect(@bank.get_rate("UAH", currency)).to be > 0
    end
  end

  it "should update itself with exchange rates from cache" do
    @bank.update_rates(@cache_path)
    NbuCurrency::CURRENCIES.each do |currency|
      expect(@bank.get_rate("UAH", currency)).to be > 0
    end
  end

  it "should export to a string a valid cache that can be reread" do
    allow(OpenURI::OpenRead).to receive(:open).with(NbuCurrency::NBU_RATES_URL) {@cache_path}
    s = @bank.save_rates_to_s
    @bank.update_rates_from_s(s)
    NbuCurrency::CURRENCIES.each do |currency|
      expect(@bank.get_rate("UAH", currency)).to be > 0
    end
  end

  it 'should set last_updated when the rates are downloaded' do
    lu1 = @bank.last_updated
    @bank.update_rates(@cache_path)
    lu2 = @bank.last_updated
    @bank.update_rates(@cache_path)
    lu3 = @bank.last_updated

    expect(lu1).not_to eq(lu2)
    expect(lu2).not_to eq(lu3)
  end

  it 'should set rates_updated_at when the rates are downloaded' do
    lu1 = @bank.rates_updated_at
    @bank.update_rates(@cache_path)
    lu2 = @bank.rates_updated_at

    expect(lu1).not_to eq(lu2)
  end

  it "should return the correct exchange rates using exchange" do
    @bank.update_rates(@cache_path)
    NbuCurrency::CURRENCIES.each do |currency|
      subunit_to_unit  = Money::Currency.wrap(currency).subunit_to_unit
      exchanged_amount = @bank.exchange(100, "UAH", currency)
      expect(exchanged_amount.cents).to eq((@exchange_rates["currencies"][currency] * subunit_to_unit).round(0).to_i)
    end
  end

  it "should return the correct exchange rates using exchange_with" do
    @bank.update_rates(@cache_path)
    NbuCurrency::CURRENCIES.each do |currency|
      subunit_to_unit  = Money::Currency.wrap(currency).subunit_to_unit
      amount_from_rate = (@exchange_rates["currencies"][currency] * subunit_to_unit).round(0).to_i

      expect(@bank.exchange_with(Money.new(100, "UAH"), currency).cents).to eq(amount_from_rate)
    end
  end

  it "should update update_rates atomically" do
    even_rates = File.expand_path(File.dirname(__FILE__) + '/even_exchange_rates.xml')
    odd_rates = File.expand_path(File.dirname(__FILE__) + '/odd_exchange_rates.xml')

    odd_thread = Thread.new do
      while true; @bank.update_rates(odd_rates); end
    end

    even_thread = Thread.new do
      while true;  @bank.update_rates(even_rates); end
    end

    # Updating bank rates so that we're sure the test won't fail prematurely
    # (i.e. even without odd_thread/even_thread getting a change to run)
    @bank.update_rates(odd_rates)

    10.times do
      rates = YAML.load(@bank.export_rates(:yaml))
      rates.delete('UAH_TO_UAH')
      rates = rates.values.collect(&:to_i)
      expect(rates.length).to eq(4)
      expect(rates).to satisfy { |rates|
        rates.all?(&:even?) or rates.all?(&:odd?)
      }
    end
    even_thread.kill
    odd_thread.kill
  end

  it "should exchange money atomically" do
    # NOTE: We need to introduce an artificial delay in the core get_rate
    # function, otherwise it will take a lot of iterations to hit some sort or
    # 'race-condition'
    Money::Bank::VariableExchange.class_eval do
      alias_method :get_rate_original, :get_rate
      def get_rate(*args)
        sleep(Random.rand)
        get_rate_original(*args)
      end
    end
    even_rates = File.expand_path(File.dirname(__FILE__) + '/even_exchange_rates.xml')
    odd_rates = File.expand_path(File.dirname(__FILE__) + '/odd_exchange_rates.xml')

    odd_thread = Thread.new do
      while true; @bank.update_rates(odd_rates); end
    end

    even_thread = Thread.new do
      while true;  @bank.update_rates(even_rates); end
    end

    # Updating bank rates so that we're sure the test won't fail prematurely
    # (i.e. even without odd_thread/even_thread getting a change to run)
    @bank.update_rates(odd_rates)

    10.times do
      expect(@bank.exchange(100, 'EUR', 'EUR').fractional).to eq(100)
    end
    even_thread.kill
    odd_thread.kill
  end
end
