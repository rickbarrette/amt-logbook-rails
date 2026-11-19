require "test_helper"

class EntrySignatureTest < ActiveSupport::TestCase
  test "signs an entry with a sealed record of the content" do
    entry = signed_entry
    sig = entry.signature
    assert_equal "Sam Supervisor", sig.signer_name
    assert_equal "A&P 1234567", sig.certificate_label
    assert_includes sig.statement, "Jane Tech performed the work"
    assert sig.intact?
  end

  test "detects changes to the entry or the signature after signing" do
    sig = signed_entry.signature
    WorkEntry.where(id: sig.work_entry_id).update_all(minutes: 600) # bypassing the model
    assert_not sig.reload.content_matches?
    assert_not sig.intact?

    sig2 = signed_entry(work_entries(:draft).tap(&:submit!)).signature
    EntrySignature.where(id: sig2.id).update_all(certificate_number: "9999999")
    assert_not sig2.reload.seal_valid?
  end

  test "signatures are permanent" do
    sig = signed_entry.signature
    assert_not sig.update(signer_name: "Someone else")
    assert_not sig.destroy
  end

  test "certificate must cover the work category (65.81)" do
    cert = users(:sup).certificates.create!(kind: "A", number: "7654321")
    err = assert_raises(ArgumentError) { EntrySignature.sign!(work_entries(:submitted), by: users(:sup), certificate: cert) }
    assert_match "doesn't cover powerplant", err.message
  end

  test "only the chosen supervisor signs a submitted entry" do
    assert_raises(ArgumentError) { EntrySignature.sign!(work_entries(:draft), by: users(:sup), certificate: user_certificates(:sup_ap)) }
  end

  test "expired certificate can't sign" do
    cert = users(:sup).certificates.create!(kind: "IA", number: "1234567", expires_on: Date.current - 1)
    assert_raises(ArgumentError) { EntrySignature.sign!(work_entries(:submitted), by: users(:sup), certificate: cert) }
  end
end
