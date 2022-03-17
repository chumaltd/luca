# frozen_string_literal: true

module LucaBook # :nodoc:
  module Code
    module_function

    def currency_code(country)
      {
        'de' => 'EUR',
        'ee' => 'EUR',
        'fr' => 'EUR',
        'gb' => 'GBP',
        'in' => 'INR',
        'it' => 'EUR',
        'nl' => 'EUR',
        'jp' => 'JPY',
        'uk' => 'GBP',
        'us' => 'USD'
      }[country]
    end
  end
end
