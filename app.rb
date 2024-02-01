
class App < Sinatra::Base

    def db
        if @db == nil
            @db = SQLite3::Database.new('./db/db.sqlite')
            @db.results_as_hash = true
        end
        return @db
    end

    get '/' do
        erb :index
    end

    get '/register' do 
        erb :register
    end

    post '/register' do
        username = params['username'] 
        cleartext_password = params['password'] 
        hashed_password = BCrypt::Password.create(cleartext_password) 
        #spara användare och hashed_password till databasen
        db.execute('INSERT INTO users (username, password) VALUES (?,?)', username, hashed_password)
        redirect "/members"
    end
    
    get '/login' do 
        @users = db.execute('SELECT * FROM users')
        erb :login
    end
    
    post '/login' do 
        username = params['username']
        cleartext_password = params['password'] 
      
        #hämta användare och lösenord från databasen med hjälp av det inmatade användarnamnet.
        user = db.execute('SELECT * FROM users WHERE username = ?', username).first
      
        #omvandla den lagrade saltade hashade lösenordssträngen till en riktig bcrypt-hash
        password_from_db = BCrypt.new(user['password'])
      
        #jämför lösenordet från databasen med det inmatade lösenordet
        if password_from_db == clertext_password 
          session[:user_id] = user['id'] 
          redirect "/"
        else
          redirect "/login"
        end


end