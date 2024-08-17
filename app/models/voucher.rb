# typed: true
# frozen_string_literal: true

class Voucher < ActiveRecord::Base
  extend T::Sig

  belongs_to :product, optional: true
  belongs_to :order, optional: true
  belongs_to :claimed_by,  class_name: 'User', optional: true
  belongs_to :created_by,  class_name: 'User', optional: true

  sig { returns(String) }
  def hyphenate
    Base32::Crockford.hypenate(code).upcase
  end

  sig { params(product: Product).returns(Voucher) }
  def self.generate!(product)
    create!(product: product, code: generate_code)
  end

  sig { returns(String) }
  def self.generate_code
    encode(SecureRandom.hex(8).to_i(16))
  end

  sig { params(code: Integer).returns(String) }
  def self.encode(code)
    Base32::Crockford.encode(code).upcase
  end

  def self.unclaimed
    where(claimed_at: nil)
  end

  sig { params(code: String).returns(T.nilable(Voucher)) }
  def self.find_voucher(code)
    code = encode(Base32::Crockford.decode(code, :integer))
    where(code: code).first
  rescue StandardError
    nil
  end

  sig { params(user: User).returns(T::Boolean) }
  def claim!(user)
    with_lock do
      reload
      raise AlreadyClaimed if claimed?

      self.claimed_by = user
      self.claimed_at = Time.current
      GrantPerks.new(product, user).perform
      save!
    end
  end

  sig { returns(T::Boolean) }
  def claimed?
    claimed_at?
  end

  AlreadyClaimed = Class.new(RuntimeError)
end
