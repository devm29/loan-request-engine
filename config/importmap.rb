# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/stimulus', to: '@hotwired--stimulus.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'
