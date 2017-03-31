var card;

jQuery(function($) {
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
    style = {
      base: {
        // Add your base input styles here. For example:
        fontSize: '18px',
        lineHeight: '24px'
      }
    };
    card = elements.create('card', {style: style});
    card.mount("#stripe-card");

    card.addEventListener('change', function(event) {
      var displayError = document.getElementById('stripe-errors');
      if (event.error) {
        displayError.textContent = event.error.message;
      } else {
        displayError.textContent = '';
      }
    });
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
  }
  function enableStripe() {
    paypalButton().removeClass("selected");
    creditCardButton().addClass("selected");
    creditCardRow().slideDown();
    orderFormSubmit().html("Secure checkout with Stripe");
  }

  orderForm().submit(function(event) {
    if (payingWithStripe()) {
      $("#stripe-errors").html("");
      // Disable the submit button to prevent repeated clicks:
      orderFormSubmit().prop('disabled', true);
      orderFormSubmit().html("<i class='fa fa-spinner fa-spin' '></i> Working...");

      stripe.createToken(card).then(function(result) {
        if (result.error) {
          var errorElement = document.getElementById('stripe-errors');
          errorElement.textContent = result.error.message;
        } else {
          stripeResponseHandler(result.token.id);
        }
      });

      // Prevent the form from being submitted:
      event.preventDefault();
      return false;
    }
  });

  function stripeResponseHandler(token) {
    postOrder(token, productId(), gift());
  }

  function postOrder(stripeToken, productId, gift) {
    $.post("orders/stripe", { stripe_token: stripeToken, product_id: productId, gift: gift}).
      done(function( data ) {
        $(".premium-page").hide();
        json = JSON.parse(data);
        $(".stripe-result").show();
        if (json['gift'] === true) {
          href = $("#voucher-claim-url").attr('href');
          href_with_code = href + "/" + json['voucher'];
          $("#voucher-claim-url").attr('href', href_with_code);
          $(".stripe-result .gift").show();
        } else {
          $(".stripe-result .mine").show();
        }
      }).
      fail(function( data ) {
        orderFailed(data);
      });
  }

  function orderFailed(response) {
    json = JSON.parse(response.responseText);
    $("#stripe-errors").html(json["charge_status"]);
    orderFormSubmit().prop('disabled', false);
    enableStripe();
  }

  function orderForm() {
    return $('form.new_order');
  }
  function orderFormSubmit() {
    return orderForm().find(".submit");
  }
  function productId() {
    return $("#order_product_id").val();
  }
  function gift() {
    return $("#order_gift_true").is(':checked');
  }
  function amount() {
    return $("#product-" + productId()).data("price");
  }
  function currency() {
    return $("#product-" + productId()).data("currency");
  }
  function creditCardRow() {
    return $(".credit-card-row");
  }
  function paypalButton() {
    return $(".paypal-button");
  }
  function creditCardButton() {
    return $(".credit-card-button");
  }
  function payingWithStripe() {
    return creditCardButton().hasClass("selected");
  }
})
