jQuery(function($) {
  enablePaypal(false);
  paypalButton().click(function() {
    enablePaypal(true);
  });
  creditCardButton().click(function() {
    enableStripe();
  });

  function enablePaypal(slide) {
    paypalButton().addClass("selected");
    creditCardButton().removeClass("selected");
    if (slide === true) {
      creditCardRow().slideUp();
    } else {
      creditCardRow().hide();
    }
    formSubmit().html("Pay with PayPal");
  }
  function enableStripe() {
    paypalButton().removeClass("selected");
    creditCardButton().addClass("selected");
    creditCardRow().slideDown();
    formSubmit().html("Secure checkout with Stripe");
  }

  form().submit(function(event) {
    if (payingWithStripe()) {
      $(".stripe-error").html("");
      // Disable the submit button to prevent repeated clicks:
      formSubmit().prop('disabled', true);
      formSubmit().html("<i class='fa fa-spinner fa-spin' '></i> Working...");

      // Request a token from Stripe:
      Stripe.source.create({
        type: 'card',
        amount: amount(),
        currency: currency(),
        card: {
          number: card().CardJs('cardNumber'),
          cvc: card().CardJs('cvc'),
          exp_month: card().CardJs('expiryMonth'),
          exp_year: card().CardJs('expiryYear')
        }
      }, stripeResponseHandler);

      // Prevent the form from being submitted:
      event.preventDefault();
      return false;
    }
  });

  function stripeResponseHandler(status, response) {
    if (status === 200) {
      console.log(gift());
      postOrder(response.id, productId(), gift());
    } else {
      stripeFailed(response);
    }
  }

  function postOrder(stripeId, productId, gift) {
    $.post("orders/stripe", { stripe_id: stripeId, product_id: productId, gift: gift}).
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
    $(".stripe-error").html(json["charge_status"]);
    formSubmit().prop('disabled', false);
    enableStripe();
  }

  function stripeFailed(response) {
    $(".stripe-error").html(response.error.message);
    formSubmit().prop('disabled', false);
    enableStripe();
  }

  function form() {
    return $('form.new_order');
  }
  function formSubmit() {
    return form().find(".submit");
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
  function card() {
    return $(".credit-card.card-js");
  }
})
