require 'rails_helper'

describe Users::RegistrationsController, type: :controller do
  describe 'POST #create' do
    let(:user_params) { { email: 'asdf@asdf.asdf', first_name: 'Register', password: '123123123' } }

    before do
      request.env["devise.mapping"] = Devise.mappings[:user]
      request.cookies['_ym_uid'] = '1234'
      request.cookies['_gid'] = '4321'
    end

    it 'starts social sharing discount experiment', experiments: 'social_sharing_discount' do
      pending 'Experiment disabled'
      expect { post :create, params: { user: user_params, locale: :ru } }.to change { UserExperiment.where(name: 'discount_for_sharing').count }.by(1)
    end

    it 'triggers Early Bird discount' do
      trigger = double(check: true)

      allow(DiscountTrigger::Service).to receive(:new).with(user: a_kind_of(User)).and_return(trigger)
      expect(trigger).to receive(:check).with(conditions: [DiscountTrigger::Conditions::EarlyBird])
      post :create, params: { user: user_params, locale: :ru }
    end

    it 'has OK response status' do
      post :create, params: { user: user_params, locale: :ru }

      expect(response.status).to eq 200
    end

    it 'creates new user' do
      post :create, params: { user: user_params, locale: :ru }

      expect(User.last.first_name).to eq 'Register'
    end

    it 'adds yandex metrika and google analytics uids to new user' do
      post :create, params: { user: user_params, locale: :ru }

      expect(User.last.yandex_metrika_uid).to eq '1234'
      expect(User.last.google_analytics_uid).to eq '4321'
    end

    it 'adds marketing data' do
      post :create, params: { user: user_params, locale: :ru }

      expect(User.last.marketing_data).to be_kind_of(MarketingData)
      expect(User.last.marketing_data.utm_params).to eq(nil)
      expect(User.last.marketing_data.cpa_partner).to eq(nil)
    end

    context 'synergia purchase' do
      it 'should create synergia widget for 1 month plan' do
        post :create, params: { user: user_params, locale: :ru, synergia: 1 }
        expect_json_keys :widget
      end

      it 'should create synergia widget for 3 months plan' do
        post :create, params: { user: user_params, locale: :ru, synergia: 3 }
        expect_json_keys :widget
      end
    end

    context 'toptraffic cookies' do
      let(:utm_params) { {
                           utm_source: 'toptraffic',
                           utm_medium: 'cpa',
                           utm_campaign: 'affiliate_id',
                           utm_term: 'transaction_id'
                       } }

      before do
        request.cookies['utm_params'] = JSON.generate(utm_params)
      end

      it 'adds toptraffic marketing data' do
        post :create, params: { user: user_params, locale: :ru }

        expect(User.last.marketing_data.utm_params).to eq(utm_params.stringify_keys)
        expect(User.last.marketing_data.marketing_partner).to eq(MarketingPartner.find_by(name: :toptraffic))
      end

      it 'invokes registration callback job' do
        allow_any_instance_of(MarketingData).to receive(:send_registration_callback?) { true }
        expect(RegistrationCallbackJob).to receive(:perform_later)
        post :create, params: { user: user_params, locale: :ru }
      end
    end

    context 'f5stat cookies' do
      let(:utm_params) { {
                           utm_source: 'f5stat',
                           utm_medium: 'cpa',
                           utm_campaign: 'cpa'
                       } }

      before do
        request.cookies['utm_params'] = JSON.generate(utm_params)
      end

      it 'adds f5stat marketing data' do
        post :create, params: { user: user_params, locale: :ru }

        expect(User.last.marketing_data.marketing_partner).to eq(MarketingPartner.find_by(name: :f5stat))
      end

      it 'invokes registration callback job' do
        allow_any_instance_of(MarketingData).to receive(:send_registration_callback?) { true }
        expect(RegistrationCallbackJob).to receive(:perform_later)
        post :create, params: { user: user_params, locale: :ru }
      end
    end
  end
end
