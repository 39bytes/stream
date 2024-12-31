client:
    cd client && gleam run -m lustre/dev start --tailwind-entry=base.css

server:
    cd server && bin/rails server
