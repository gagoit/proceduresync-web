class CheckReturnDocInfo
  include ::RSpec::Matchers

  def test doc_info, doc
    expect(doc_info["uid"]).to eq(doc.id.to_s)
    expect(doc_info["title"]).to eq(doc.title)
    expect(doc_info["doc_file"]).to eq(doc.current_version.doc_file)
    expect(doc_info["version"]).to eq(doc.current_version.version)

    expect(doc_info["category"]).to eq(doc.reload.category.try(:name).to_s)
    expect(doc_info["id"]).to eq(doc.doc_id)

    expect(doc_info["expiry"]).to eq(doc.expiry.utc.to_s) if doc_info.has_key?("expiry")
    expect(doc_info["created_at"]).to eq(doc.created_at.utc.to_s) if doc_info.has_key?("created_at")
    expect(doc_info["updated_at"]).to eq(doc.updated_at.utc.to_s) if doc_info.has_key?("updated_at")
  end
end