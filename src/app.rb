
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
            redirect '/login' # SKickas hit om användare inte är inloggad
        end
    end

    get '/login/register' do 
        erb :register
    end

    post '/login/register' do
        username = params['username'] 
        cleartext_password = params['password'] 
        hashed_password = BCrypt::Password.create(cleartext_password) 
        admin = 0
        existing_user = db.execute('SELECT * FROM users WHERE username = ?', username).first
        #spara användare och hashed_password till databasen
        if existing_user.nil?
            db.execute('INSERT INTO users (username, password, admin) VALUES (?,?,?)', username, hashed_password, admin)
            redirect "/login"
        end
        redirect "/login"
    end

    post '/login/register_admin' do
        username = params['username'] 
        cleartext_password = params['password'] 
        hashed_password = BCrypt::Password.create(cleartext_password) 
        admin = 1
        existing_user = db.execute('SELECT * FROM users WHERE username = ?', username).first
        #spara användare och hashed_password till databasen
        if existing_user.nil?
            db.execute('INSERT INTO users (username, password, admin) VALUES (?,?,?)', username, hashed_password, admin)
            redirect "/login"
        end
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

    post '/delete_review/:id' do |id|
        db.execute('DELETE FROM reviews WHERE review_id = ?', id)
        current_page_url = request.referrer
        redirect current_page_url
    end


    get '/' do
        erb :index
    end

    get '/episodes' do
        @themes = db.execute('SELECT id, category FROM themes').map { |theme| { id: theme['id'], category: theme['category'] } }
        @episodes = db.execute('SELECT * FROM episodes')
        erb :episodes_menu
    end
      
    post '/episodes' do
        @themes = db.execute('SELECT id, category FROM themes').map { |theme| { id: theme['id'], category: theme['category'] } }
        @theme_id = params[:theme_id]
        
        if @theme_id && !@theme_id.empty? && @theme_id != 2 
          @episodes = db.execute('SELECT episodes.* FROM episodes
                                  INNER JOIN sort ON episodes.id = sort.episode_id
                                  WHERE sort.theme_id = ?', @theme_id)
        else
          @episodes = db.execute('SELECT * FROM episodes')
        end
        
        erb :episodes_menu
    end

      

    get '/episodes/:id' do |episode_id|
        user_id = session[:user_id]
        @episode = db.execute('SELECT * FROM episodes WHERE id=?', episode_id).first
        @reviews = db.execute('SELECT * FROM reviews WHERE episode_id=? ORDER BY time DESC', episode_id)
        @user = db.execute('SELECT * FROM users WHERE user_id=?', user_id)
        puts "@episode: #{@episode.inspect}" # Debugging
        erb :episode_page
    end
    
    post '/episodes/:id' do |episode_id|
        review = h(params['review'])
        user_id = session[:user_id]
        # Lägg till user + review + tid 
        current_time = Time.now.strftime('%Y-%m-%d %H:%M:%S')
        db.execute('INSERT INTO reviews (user_id, review, episode_id,time) VALUES (?, ?, ?,?)', user_id, review, episode_id, current_time)
        current_page_url = request.referrer
        redirect current_page_url
    end

    helpers do
        def h(review)
            Rack::Utils.escape_html(review)
        end
    end



    post '/favorites/add' do
        episode_id = params['episode_id']
        user_id = session[:user_id] 
        existing_favorite = db.execute('SELECT * FROM favorites WHERE user_id = ? AND episode_id = ?', user_id, episode_id).first
        if existing_favorite
            current_page_url = request.referrer
            redirect current_page_url
        else
            db.execute('INSERT INTO favorites (user_id, episode_id) VALUES (?, ?)', user_id, episode_id)
            current_page_url = request.referrer
            redirect current_page_url
        end
    
        # Meddelande
        status 200
        body 'Episode added to favorites successfully'
        current_page_url = request.referrer
        redirect current_page_url
    end
    
    


end