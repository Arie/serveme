# typed: false
# frozen_string_literal: true

# Pin npm packages by running ./bin/importmap

pin 'application', preload: true
pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js', preload: true
pin_all_from 'app/javascript/controllers', under: 'controllers', preload: true
pin 'trix'
pin '@rails/actiontext', to: 'actiontext.js'
pin 'popper', to: 'popper.js', preload: true

pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.2.0/dist/chart.js", preload: true
pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js", preload: true

pin 'bootstrap', to: 'bootstrap.min.js', preload: true
