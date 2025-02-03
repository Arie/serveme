var card;

jQuery(document).on('turbo:load', function() {
  enablePaypal(false);
  paypalButton().click(function() {
    enablePaypal(true);
  });
  creditCardButton().click(function() {
    enableStripe();
  });
  if (orderForm().length > 0) {
    setupStripe();
  }

  function setupStripe() {
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

    // Create and mount the card element
    card = elements.create('card', {
      style: style,
      hidePostalCode: true
    });
    card.mount("#stripe-card");

    // Handle real-time validation errors
    card.addEventListener('change', function(event) {
      const displayError = document.getElementById('stripe-errors');
      if (event.error) {
        showError(event.error.message);
      } else {
        clearError();
      }
    });
  }

  function showError(message) {
    const displayError = document.getElementById('stripe-errors');
    displayError.textContent = message;
    displayError.style.display = 'block';
    orderFormSubmit().prop('disabled', false);
    orderFormSubmit().html("Secure checkout with Stripe");
  }

  function clearError() {
    const displayError = document.getElementById('stripe-errors');
    displayError.textContent = '';
    displayError.style.display = 'none';
  }

  function showProcessing(message) {
    orderFormSubmit().prop('disabled', true);
    orderFormSubmit().html(`<i class='fa fa-spinner fa-spin'></i> ${message}`);
    clearError();
  }

  function enablePaypal(slide) {
    paypalButton().addClass("selected");
    creditCardButton().removeClass("selected");
    if (slide === true) {
      creditCardRow().slideUp();
    } else {
      creditCardRow().hide();
    }
    orderFormSubmit().html("Pay with PayPal");

    // Add PayPal-specific handling
    orderForm().off('submit.paypal').on('submit.paypal', function(event) {
      if (!payingWithStripe()) {
        showProcessing("Redirecting to PayPal...");
      }
    });
  }

  function enableStripe() {
    paypalButton().removeClass("selected");
    creditCardButton().addClass("selected");
    creditCardRow().slideDown();
    orderFormSubmit().html("Secure checkout with Stripe");
  }

  orderForm().submit(function(event) {
    if (payingWithStripe()) {
      clearError();
      showProcessing("Processing payment...");

      // Create a payment method
      stripe.createPaymentMethod({
        type: 'card',
        card: card,
        billing_details: {}
      }).then(function(result) {
        if (result.error) {
          showError(result.error.message);
        } else {
          createPaymentIntent(result.paymentMethod.id);
        }
      });

      event.preventDefault();
      return false;
    }
  });

  function createPaymentIntent(paymentMethodId) {
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
        // After 3D Secure, check the payment status from server
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
    // Fade out the form
    $(".premium-page").fadeOut(300, function() {
      // Hide both success messages initially
      $(".stripe-result .gift, .stripe-result .mine").hide();

      // Show the appropriate success message
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

      // Show the result container
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
    enableStripe();
  }

  // Helper functions
  function orderForm() { return $('form.new_order'); }
  function orderFormSubmit() { return orderForm().find(".submit"); }
  function productId() { return $("#order_product_id").val(); }
  function gift() { return $("#order_gift_true").is(':checked'); }
  function creditCardRow() { return $(".credit-card-row"); }
  function paypalButton() { return $(".paypal-button"); }
  function creditCardButton() { return $(".credit-card-button"); }
  function payingWithStripe() { return creditCardButton().hasClass("selected"); }
});
