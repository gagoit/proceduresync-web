require 'test_helper'

class DocumentsControllerTest < ActionController::TestCase
  setup do
    @document = documents(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:documents)
  end

  test "should create document" do
    assert_difference('Documents.count') do
      post :create, document: {  }
    end

    assert_response 201
  end

  test "should show document" do
    get :show, id: @document
    assert_response :success
  end

  test "should update document" do
    put :update, id: @document, document: {  }
    assert_response 204
  end

  test "should destroy document" do
    assert_difference('Documents.count', -1) do
      delete :destroy, id: @document
    end

    assert_response 204
  end
end
