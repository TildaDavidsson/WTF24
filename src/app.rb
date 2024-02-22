
class App < Sinatra::Base
    enable :sessions

    def db
        if @db == nil
            @db = SQLite3::Database.new('../db/db.sqlite')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/login' do
        @user =  db.execute('SELECT * FROM users WHERE user_id = ?', session[:user_id]).first
        erb :login
    end
    
    post '/login' do 
        username = params['username']
        cleartext_password = params['password'] 
        
        # Retrieve user from the database
        user = db.execute('SELECT * FROM users WHERE username = ?', username).first
        
        if user.nil?
          redirect "login/register" # or redirect to login with an error message
        else
          hashed_password_from_db = user['password'] # Retrieve hashed password from the database
          
          if BCrypt::Password.new(hashed_password_from_db) == cleartext_password 
             session[:user_id] = user['user_id'] # Set session data
             redirect "/profile"
          else
             redirect "/login"
          end
        end
    end
      
    
    get '/profile' do
        if session[:user_id]
            user_id = session[:user_id]
            @user = db.execute('SELECT * FROM users WHERE user_id = ?', session[:user_id]).first
            @user_favorites = db.execute('SELECT * FROM favorites WHERE user_id = ?', user_id)
            @favorite_episodes = []
            @reviews = db.execute('SELECT * FROM reviews WHERE user_id = ?', session[:user_id])


            @user_favorites.each do |favorite|
              episode = db.execute('SELECT * FROM episodes WHERE id = ?', favorite['episode_id']).first
              @favorite_episodes << episode['title'] if episode
            end
            erb :profile
        else
            redirect '/login' # Redirect to login if user is not logged in
        end
    end

    get '/login/register' do 
        erb :register
    end

    post '/login/register' do
        username = params['username'] 
        cleartext_password = params['password'] 
        hashed_password = BCrypt::Password.create(cleartext_password) 
        #spara användare och hashed_password till databasen
        db.execute('INSERT INTO users (username, password) VALUES (?,?)', username, hashed_password)
        redirect "/login"
    end

    post '/logout' do
        session.clear
        redirect '/'
    end

    post '/delete_account' do 
        user_id = session[:user_id]
        db.execute('DELETE FROM users WHERE user_id = ?', user_id)
        db.execute('DELETE FROM reviews WHERE user_id = ?', user_id)
        db.execute('DELETE FROM favorites WHERE user_id = ?', user_id)
        session.clear
        redirect "/"
    end

    get '/' do
        erb :index
    end

    get '/episodes' do
        user_id = session[:user_id]
        @episodes = db.execute('SELECT * FROM episodes;')
        puts "@episodes: #{@episodes.inspect}" # Debugging statement
        erb :episodes_menu
    end

    get '/episodes/:id' do |episode_id|
        user_id = session[:user_id]
        @episode = db.execute('SELECT * FROM episodes WHERE id=?', episode_id).first
        @reviews = db.execute('SELECT * FROM reviews WHERE episode_id=? ORDER BY time DESC', episode_id)
        @user = db.execute('SELECT * FROM users WHERE user_id=?', user_id)
        puts "@episode: #{@episode.inspect}" # Debugging statement
        erb :episode_page
    end
    
    post '/episodes/:id' do |episode_id|
        review = params['review']
        user_id = session[:user_id]
        # Insert the review into the reviews table
        current_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        db.execute('INSERT INTO reviews (user_id, review, episode_id,time) VALUES (?, ?, ?,?)', user_id, review, episode_id, current_time)
        current_page_url = request.referrer
        redirect current_page_url
    end

    post '/favorites/add' do
        episode_id = params['episode_id']
        user_id = session[:user_id] # Assuming user is logged in
        existing_favorite = db.execute('SELECT * FROM favorites WHERE user_id = ? AND episode_id = ?', user_id, episode_id).first
        if existing_favorite
            current_page_url = request.referrer
            redirect current_page_url
        else
            db.execute('INSERT INTO favorites (user_id, episode_id) VALUES (?, ?)', user_id, episode_id)
            current_page_url = request.referrer
            redirect current_page_url
        end
    
        # Respond with success message or appropriate JSON response
        status 200
        body 'Episode added to favorites successfully'
        current_page_url = request.referrer
        redirect current_page_url
    end
    
    


end