Rails.application.routes.draw do
  get 'users/index'

  get 'users/conf'

  get 'users/stock'
  
  post 'index' => 'users/conf'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
