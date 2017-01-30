jQuery(function($) {
  var $form = $('form.new_order');
  $form.submit(function(event) {
    // Disable the submit button to prevent repeated clicks:
    $form.find('.submit').prop('disabled', true);

    // Request a token from Stripe:
    console.log(productId());
    console.log(amount());
    console.log(currency());
    Stripe.source.create({
      type: 'card',
      amount: amount(),
      currency: currency(),
      redirect: {
        return_url: 'https://shop.foo.com/crtA6B28E1'
      }
    }, stripeResponseHandler);

    // Prevent the form from being submitted:
    event.preventDefault();
    return false;
  });

  function stripeResponseHandler(status, response) {
    console.log(status);
    console.log(response);
  }

  function productId() {
    console.log($("#order_product_id"));
    $("#order_product_id").val();
  }
  function amount() {
    $("#product-" + productId()).data("price");
  }
  function currency() {
    $("#product-" + productId()).data("currency");
  }
})
