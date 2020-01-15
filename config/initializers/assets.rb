# Explicitly register the extensions we are interested in compiling
Rails.application.config.assets.precompile << [
    "*.html", "*.erb", "*.haml",
    "*.css", "*.sass",
    "*.png", "*.gif", ".jpg", ".jpeg",
    "*.eot", "*.otf", "*.svc", "*.woff", ".woff2", ".ttf"
]
#Rails.application.config.assets.precompile += %w( application.css application.js )