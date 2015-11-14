require 'test_helper'

class PermissionsControllerTest < ActionController::TestCase
  setup do
    @permission = permissions(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:permissions)
  end

  test "should create permission" do
    assert_difference('Permission.count') do
      post :create, permission: {  }
    end

    assert_response 201
  end

  test "should show permission" do
    get :show, id: @permission
    assert_response :success
  end

  test "should update permission" do
    put :update, id: @permission, permission: {  }
    assert_response 204
  end

  test "should destroy permission" do
    assert_difference('Permission.count', -1) do
      delete :destroy, id: @permission
    end

    assert_response 204
  end
end
