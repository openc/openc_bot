# frozen_string_literal: true

require_relative "../spec_helper"
require "openc_bot"
require "openc_bot/pseudo_machine_company_fetcher_bot"

Mail.defaults do
  delivery_method :test # no, don't send emails when testing
end

module TestPseudoMachineCompaniesFetcher
  extend OpencBot::PseudoMachineCompanyFetcherBot
end

describe OpencBot::PseudoMachineCompanyFetcherBot do
  context "when a module extends PseudoMachineCompanyFetcherBot" do
    it "includes CompanyFetcherBot methods" do
      expect(TestPseudoMachineCompaniesFetcher).to respond_to(:inferred_jurisdiction_code)
    end
  end
end
