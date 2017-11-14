Rails.application.routes.draw do
  devise_for :users
  get 'users/index'
  get '/users/index'
  
  get 'users/conf'
  get '/users/conf'

  get 'users/stock'
  get '/users/stock'
  
  post 'users/index' => 'users/index'
  
  post 'users/conf' => 'users/conf'
  
  root to:'users#index'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
