# typed: false

require "spec_helper"

RSpec.describe SdrController, type: :controller do
  let(:user) { create(:user) }
  before { sign_in user }
  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to be_successful
    end

    context "with full connect string" do
      let(:server) { create(:server, ip: "1.2.3.4", port: 27015) }
      let(:reservation) { create(:reservation, server: server, sdr_ip: "5.6.7.8", sdr_port: 27015) }

      before do
        allow(Addrinfo).to receive(:getaddrinfo).with("bolus.fakkelbrigade.eu", nil, Socket::AF_INET)
          .and_return([ double(ip_address: "1.2.3.4") ])
        reservation
        get :index, params: { ip_port: 'connect bolus.fakkelbrigade.eu:27015; password "foobarwidget"' }
      end

      it "returns success" do
        expect(response).to be_successful
      end

      it "assigns result as full connect string" do
        expect(assigns(:result)).to eq('connect 5.6.7.8:27015; password "foobarwidget"')
      end
    end

    context "with simple ip:port" do
      let(:server) { create(:server, ip: "1.2.3.4", port: 27015) }
      let(:reservation) { create(:reservation, server: server, sdr_ip: "5.6.7.8", sdr_port: 27015) }

      before do
        allow(Addrinfo).to receive(:getaddrinfo).with("bolus.fakkelbrigade.eu", nil, Socket::AF_INET)
          .and_return([ double(ip_address: "1.2.3.4") ])
        reservation
        get :index, params: { ip_port: "bolus.fakkelbrigade.eu:27015" }
      end

      it "returns success" do
        expect(response).to be_successful
      end

      it "assigns result as sdr ip port" do
        expect(assigns(:result)).to eq("5.6.7.8:27015")
      end
    end

    context "with resolved ip when server has hostname" do
      let(:server) { create(:server, ip: "bolus.fakkelbrigade.eu", port: 27015) }
      let(:reservation) { create(:reservation, server: server, sdr_ip: "5.6.7.8", sdr_port: 27015) }

      before do
        server.update_column(:resolved_ip, "1.2.3.4")
        reservation
        get :index, params: { ip_port: "1.2.3.4:27015" }
      end

      it "returns success" do
        expect(response).to be_successful
      end

      it "finds server by resolved_ip and returns sdr ip port" do
        expect(assigns(:result)).to eq("5.6.7.8:27015")
      end
    end

    context "with resolved ip in connect string when server has hostname" do
      let(:server) { create(:server, ip: "bolus.fakkelbrigade.eu", port: 27015) }
      let(:reservation) { create(:reservation, server: server, sdr_ip: "5.6.7.8", sdr_port: 27015) }

      before do
        server.update_column(:resolved_ip, "1.2.3.4")
        reservation
        get :index, params: { ip_port: 'connect 1.2.3.4:27015; password "foobarwidget"' }
      end

      it "returns success" do
        expect(response).to be_successful
      end

      it "assigns result as full connect string with sdr ip" do
        expect(assigns(:result)).to eq('connect 5.6.7.8:27015; password "foobarwidget"')
      end
    end
  end
end
