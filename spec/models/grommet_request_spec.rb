require 'rails_helper'

# def resubmit
#   registrant = nil
#   params = YAML::load(self.request_params).with_indifferent_access
#   [:rocky_request, :voter_records_request, :voter_registration].tap do |keys|
#     value = params
#     keys.each do |key|
#       unless (value = value[key.to_s])
#         raise "Invalid request: parameter #{keys.join('.')} not found"
#       end
#     end
#   end
#   registrant = V3::RegistrationService.create_pa_registrant(params[:rocky_request])
#   registrant.basic_character_replacement!
#   if registrant.valid?
#     # If valid for rocky, ensure that it's valid for PA submissions
#     pa_validation_errors = V3::RegistrationService.valid_for_pa_submission(registrant)
#     if pa_validation_errors.any?
#       raise pa_validation_errors.inspect
#     else
#       # If there are no errors, make the submission to PA
#       # This will commit the registrant with the response code
#       registrant.save!
#       V3::RegistrationService.delay.async_register_with_pa(registrant.id)
#       return true
#     end
#   else
#     raise registrant.errors.full_messages.join("\n")
#   end
# end
  
RSpec.describe GrommetRequest, :type => :model do
  let(:rocky_request) do
    {
      voter_records_request: {
        voter_registration: "voter_registration"
      }
    }
  end
  let(:grommet_req) do 
    GrommetRequest.new({
      request_params: {
        rocky_request: rocky_request
      }.to_yaml
    })     
  end
  let(:registrant) { mock_model(Registrant) }
  let(:delay) { double("Delay") }
  before(:each) do
    allow(registrant).to receive(:valid?) { true }
    allow(registrant).to receive(:basic_character_replacement!) 
    allow(registrant).to receive(:save!) 
    allow(registrant).to receive(:state_ovr_data=)    
    allow(registrant).to receive(:state_ovr_data) { {} }    
    allow(registrant).to receive(:id) { "id" }     
    allow(V3::RegistrationService).to receive(:valid_for_pa_submission) { [] }
    allow(V3::RegistrationService).to receive(:create_pa_registrant) { registrant }
    allow(delay).to receive(:async_register_with_pa).with(registrant.id)
    allow(V3::RegistrationService).to receive(:delay) { delay }
  end
  describe "resubmit" do    
    subject { grommet_req.resubmit }
    it "creates a new pa_registrant" do
      expect(V3::RegistrationService).to receive(:create_pa_registrant).with(rocky_request)
      subject
    end
    it "runs the basic character replacements" do
      expect(registrant).to receive(:basic_character_replacement!)
      subject
    end
    context "when registrant is not valid" do
      before(:each) do
        allow(registrant).to receive(:valid?) { false }
      end
      it "raises an error" do
        expect { 
          subject
        }.to raise_error
      end
    end
    context "when registrant is valid" do 
      it "checks for PA validity" do
        expect(V3::RegistrationService).to receive(:valid_for_pa_submission) { [] }
        subject
      end
      context "if not valid for pa" do
        before(:each) do
          allow(V3::RegistrationService).to receive(:valid_for_pa_submission) { ["an error"] }          
        end
        it "raises an error" do
          expect { 
            subject
          }.to raise_error
        end
      end
      context "if valid for pa" do
        it "commits the registrant" do
          expect(registrant).to receive(:save!)
          subject
        end
        it "queues a PA registration" do
          expect(delay).to receive(:async_register_with_pa).with(registrant.id)
          subject
        end
        it "returns true" do
          expect(subject).to be_truthy
        end
      end
    end
  end
end
