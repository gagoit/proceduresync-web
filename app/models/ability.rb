class Ability
  include CanCan::Ability

  def initialize(user)

    user ||= User.new

    #users
    alias_action :read, :create, :update, :to => :write

    if user.admin?
      can :access, :rails_admin   # grant access to rails_admin
      can :dashboard              # grant access to the dashboard

      can [:create, :update, :read], :all

      cannot :destroy, :all
    
      can :bulk_upload, Company
      can :generate_invoice, Company

      cannot [:create, :update, :delete], Invoice
    elsif user.super_help_desk_user
      can :access, :rails_admin   # grant access to rails_admin
      can :dashboard              # grant access to the dashboard

      can [:create, :update, :read], :all
      
      cannot [:create], Company
      cannot :destroy, :all  

      can :bulk_upload, Company
      can :generate_invoice, Company

      cannot [:create, :update, :delete], Invoice
    else
      can :update, user, :id => user.id
      can :setup, user, :id => user.id
      can :change_company_view

      #custom permission
    end

  end
end
