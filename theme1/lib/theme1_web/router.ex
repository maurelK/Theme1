defmodule Theme1Web.Router do
  use Theme1Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Authentication routes issue or clear the session cookie and are publicly reachable.
  scope "/api/auth", Theme1Web do
    pipe_through :api

    post "/login", AuthController, :login
    get "/csrf", AuthController, :csrf
    post "/password-reset/request", AuthController, :request_password_reset
    post "/password-reset/confirm", AuthController, :reset_password
    post "/accept-invitation", AuthController, :accept_invitation
  end

  # Session restoration requires the signed JWT and matching CSRF header.
  pipeline :authenticated_api do
    plug Theme1Web.AuthPlug
  end

  # Administrator routes require both authentication and an administrator role.
  pipeline :administrator_api do
    plug Theme1Web.RolePlug, :administrator
  end

  # Review routes are available to managers, HR/payroll, and administrators.
  pipeline :reviewer_api do
    plug Theme1Web.RolePlug, [:manager, :hr_payroll, :administrator]
  end

  scope "/api/auth", Theme1Web do
    pipe_through [:api, :authenticated_api]

    # Logout is state-changing, so it must carry the same JWT and CSRF proof.
    post "/logout", AuthController, :logout
    get "/session", AuthController, :session
    post "/password", AuthController, :change_password
  end

  # Authenticated clients may read the fixed role catalog, but cannot mutate it.
  scope "/api", Theme1Web do
    pipe_through [:api, :authenticated_api]

    get "/roles", RoleController, :index
    get "/teams", TeamController, :index
  end

  # Role promotion and demotion are restricted to administrators.
  scope "/api/admin", Theme1Web do
    pipe_through [:api, :authenticated_api, :administrator_api]

    put "/users/:userID/role", AdminController, :update_role
    post "/teams", TeamController, :create
    post "/teams/:teamID/members/:userID", TeamController, :add_member
    delete "/teams/:teamID/members/:userID", TeamController, :remove_member
  end

  scope "/", Theme1Web do
    pipe_through :api

    get "/", HealthController, :index
  end

  scope "/api", Theme1Web do
    # All existing business data now requires a verified JWT and CSRF header.
    pipe_through [:api, :authenticated_api]
    post "/workingtime/:id/correction-requests", CorrectionRequestController, :create
    #Clock
    get "/clocks/:userID", ClockController, :index
    post "/clocks/:userID", ClockController, :create 
    get "/workingtime/:userID", WorkingTimeController, :index
    get "/workingtime/:userID/:id", WorkingTimeController, :show
    post "/workingtime/:userID", WorkingTimeController, :create
    put "/workingtime/:id", WorkingTimeController, :update
    delete "/workingtime/:id", WorkingTimeController, :delete

    get "/users", UserController, :index
    post "/users", UserController, :create
    get "/users/:userID", UserController, :show
    put "/users/:userID", UserController, :update
    delete "/users/:userID", UserController, :delete
  end

  # Reviewers can inspect and decide employee correction requests.
  scope "/api/reviews", Theme1Web do
    pipe_through [:api, :authenticated_api, :reviewer_api]

    get "/correction-requests", CorrectionRequestController, :index
    put "/correction-requests/:id", CorrectionRequestController, :review
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:theme1, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]
  
      live_dashboard "/dashboard", metrics: Theme1Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
