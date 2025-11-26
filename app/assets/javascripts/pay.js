var elements;
var expressCheckoutElement;
var cardElement;
var stripeInitialized = false;

jQuery(document).on('turbo:before-visit', function() {
  stripeInitialized = false;
  elements = null;
  expressCheckoutElement = null;
  cardElement = null;
});

jQuery(document).on('turbo:load', function() {
  if (orderForm().length === 0) return;

  if (!stripeInitialized) {
    initializeStripeElements();
    stripeInitialized = true;
  }

  $('#order_product_id').on('change', function() {
    var product = getSelectedProduct();
    if (product && elements) {
      elements.update({
        amount: product.price,
        currency: product.currency
      });
    }
  });

  cardButton().click(function(event) {
    event.preventDefault();
    creditCardRow().removeClass('d-none');
  });

  paypalButton().on('mousedown', function() {
    creditCardRow().addClass('d-none');
  });

  paypalButton().click(function() {
    var btn = $(this);
    btn.html('<i class="fa fa-spinner fa-spin"></i>');
    cardButton().prop('disabled', true).css('opacity', '0.5');
    $('.express-checkout-section').css('pointer-events', 'none').css('opacity', '0.5');
    setTimeout(function() {
      btn.prop('disabled', true);
    }, 100);
  });

  orderForm().submit(function(event) {
    if (!creditCardRow().hasClass('d-none')) {
      event.preventDefault();
      clearError();
      showProcessing("Processing payment...");

      stripe.createPaymentMethod({
        type: 'card',
        card: cardElement,
        billing_details: {}
      }).then(function(result) {
        if (result.error) {
          showError(result.error.message);
        } else {
          createCardPaymentIntent(result.paymentMethod.id);
        }
      });

      return false;
    }
  });

  function initializeStripeElements() {
    var product = getSelectedProduct();
    if (!product) return;

    elements = stripe.elements({
      mode: 'payment',
      amount: product.price,
      currency: product.currency
    });

    if (expressCheckoutElement) {
      expressCheckoutElement.unmount();
    }

    expressCheckoutElement = elements.create('expressCheckout', {
      buttonType: {
        googlePay: 'buy',
        applePay: 'buy'
      },
      buttonTheme: {
        googlePay: 'black',
        applePay: 'black'
      },
      layout: {
        overflow: 'never'
      },
      paymentMethods: {
        googlePay: 'always',
        applePay: 'always',
        link: 'auto',
        amazonPay: 'auto'
      }
    });

    expressCheckoutElement.mount('#express-checkout-element');

    var paymentMethodsRevealed = false;

    function revealPaymentMethods(hasWalletMethods) {
      if (paymentMethodsRevealed) return;
      paymentMethodsRevealed = true;

      $('.payment-loading').addClass('d-none');

      if (!hasWalletMethods) {
        $('.express-checkout-section').addClass('d-none');
        $('.express-checkout-divider').addClass('d-none');
      }

      $('.payment-methods-wrapper').addClass('visible');
    }

    setTimeout(function() {
      revealPaymentMethods(false);
    }, 3000);

    expressCheckoutElement.on('ready', function(event) {
      var availablePaymentMethods = event.availablePaymentMethods;
      var hasWalletMethods = availablePaymentMethods && Object.values(availablePaymentMethods).some(function(v) { return v === true; });
      revealPaymentMethods(hasWalletMethods);
    });

    expressCheckoutElement.on('click', function(event) {
      event.resolve();
    });

    expressCheckoutElement.on('confirm', async function() {
      showProcessing("Processing payment...");

      try {
        var response = await createExpressPaymentIntent();

        if (response.error) {
          showError(response.error);
          return;
        }

        const { error } = await stripe.confirmPayment({
          elements: elements,
          clientSecret: response.client_secret,
          confirmParams: {
            return_url: stripeReturnUrl
          }
        });

        if (error) {
          showError(error.message);
        }
      } catch (err) {
        showError("Payment failed. Please try again.");
      }
    });

    if (cardElement) {
      cardElement.unmount();
    }

    const style = {
      base: {
        fontSize: '16px',
        color: '#32325d',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
        fontSmoothing: 'antialiased',
        '::placeholder': {
          color: '#aab7c4'
        },
        ':-webkit-autofill': {
          color: '#32325d',
        },
      },
      invalid: {
        color: '#fa755a',
        iconColor: '#fa755a',
        '::placeholder': {
          color: '#FFCCA5',
        },
      }
    };

    cardElement = elements.create('card', {
      style: style,
      hidePostalCode: true
    });
    cardElement.mount("#stripe-card");

    cardElement.addEventListener('change', function(event) {
      if (event.error) {
        showError(event.error.message);
      } else {
        clearError();
      }
    });
  }

  async function createExpressPaymentIntent() {
    var response = await $.post("/orders/create_express_payment_intent", {
      product_id: productId(),
      gift: gift()
    });
    return response;
  }

  function createCardPaymentIntent(paymentMethodId) {
    showProcessing("Creating payment...");

    $.post("/orders/create_payment_intent", {
      payment_method_id: paymentMethodId,
      product_id: productId(),
      gift: gift()
    }).done(function(response) {
      if (response.success) {
        handlePaymentSuccess(response);
      } else if (response.requires_action) {
        handleCardAction(response);
      } else {
        showError(response.error || "Payment failed");
      }
    }).fail(function(response) {
      orderFailed(response);
    });
  }

  function handleCardAction(response) {
    showProcessing("Verifying payment...");

    stripe.confirmCardPayment(response.payment_intent_client_secret).then(function(result) {
      if (result.error) {
        showError(result.error.message);
      } else {
        $.get("/orders/status", {
          payment_intent_id: result.paymentIntent.id
        }).done(function(response) {
          handlePaymentSuccess(response);
        }).fail(function(response) {
          orderFailed(response);
        });
      }
    });
  }

  function handlePaymentSuccess(response) {
    $(".premium-page").fadeOut(300, function() {
      $(".stripe-result .gift, .stripe-result .mine").hide();

      if (response.gift) {
        if (response.voucher) {
          var href = $("#voucher-claim-url").attr('href');
          var href_with_code = href + "/" + response.voucher;
          $("#voucher-claim-url").attr('href', href_with_code);
          $("#voucher-claim-url").parent().show();
        }
        $(".stripe-result .gift").fadeIn(300);
      } else {
        $(".stripe-result .mine").fadeIn(300);
      }

      $(".stripe-result").fadeIn(300);
    });
  }

  function orderFailed(response) {
    try {
      var json = JSON.parse(response.responseText);
      showError(json.error || json.charge_status || "Payment failed. Please try again.");
    } catch (e) {
      showError("Payment failed. Please try again.");
    }
  }

  function showError(message) {
    var displayError = document.getElementById('stripe-errors');
    displayError.textContent = message;
    displayError.style.display = 'block';
    orderFormSubmit().prop('disabled', false);
    updateSubmitButton();
  }

  function clearError() {
    var displayError = document.getElementById('stripe-errors');
    displayError.textContent = '';
    displayError.style.display = 'none';
  }

  function showProcessing(message) {
    orderFormSubmit().prop('disabled', true);
    orderFormSubmit().html("<i class='fa fa-spinner fa-spin'></i> " + message);
    clearError();
  }

  function updateSubmitButton() {
    orderFormSubmit().html("Pay");
  }

  function getSelectedProduct() {
    var selectedProductId = $('#order_product_id').val();
    var productEl = document.getElementById('product-' + selectedProductId);
    if (!productEl) return null;

    return {
      id: productEl.dataset.productId,
      currency: productEl.dataset.currency,
      price: parseInt(productEl.dataset.price, 10)
    };
  }

  function orderForm() { return $('form.new_order'); }
  function orderFormSubmit() { return $('.submit'); }
  function productId() { return $("#order_product_id").val(); }
  function gift() { return $("#order_gift_true").is(':checked'); }
  function creditCardRow() { return $(".credit-card-row"); }
  function paypalButton() { return $(".paypal-btn"); }
  function cardButton() { return $(".card-btn"); }
});
