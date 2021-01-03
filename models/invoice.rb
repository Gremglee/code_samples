class Invoice < ApplicationRecord
  include AASM

  belongs_to :coin_transaction
  belongs_to :user

  has_one :notification, as: :notificable

  aasm column: 'state' do
    state :created, initial: true
    state :failed, :paid, :chargebacked

    event :pay do
      transitions from: :created, to: :paid
    end

    event :chargeback do
      transitions from: :paid, to: :chargebacked
    end

    event :fail do
      transitions from: :created, to: :failed
    end
  end
end
