# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe UserDecorator do
  let(:user) { build(:server, name: 'Name') }
  subject { UserDecorator.new(user) }

  describe '#nickname' do
    context 'donator' do
      it 'decorates the nickname with a donator icon' do
        user.stub(donator?: true)
        user.stub(nickname: 'Foo')
        subject.nickname.should == '<span class="donator">Foo <icon class="fa fa-star" title="Premium"></icon></span>'
      end

      it 'escapes HTML in the nickname to prevent XSS' do
        user.stub(donator?: true)
        user.stub(nickname: '<script>alert(1)</script>')
        expect(subject.nickname).not_to include('<script>')
        expect(subject.nickname).to include('&lt;script&gt;')
      end
    end

    context 'non-donator' do
      it 'does not decorate the nickname with the donator icon' do
        user.stub(donator?: false)
        user.stub(nickname: 'Bar')
        subject.nickname.should == 'Bar'
      end
    end
  end
end
