# LearnLoop — Products, Checkout & Discounts

The storefront sells digital products (PDFs, templates, courses, coaching). Stripe handles payments. Products are separate from community membership.

See SKILL.md for `ll` / `ll_pub` helpers.

---

## Products (admin)

### List all products
```bash
ll GET /admin/products
```

### Create a product
```bash
ll POST /admin/products -d '{
  "title": "Prompt Engineering Toolkit",
  "description": "100 battle-tested prompts for creators.",
  "priceAmount": 2700,
  "currency": "usd",
  "productType": "digital",
  "coverImageUrl": "https://r2.learnloop.cc/products/toolkit-cover.jpg"
}'
```

`priceAmount` is in **cents** (`2700` = $27.00). Synced to Stripe automatically on create.

### Update a product (syncs price to Stripe)
```bash
PRODUCT_ID="..."
ll PATCH /admin/products/$PRODUCT_ID -d '{
  "title": "Updated Title",
  "priceAmount": 3700
}'
```

### Upload fulfillment file (PDF, zip, etc.)
```bash
# First upload to R2
UPLOAD=$(curl -s -X POST "$LL_URL/admin/upload" \
  -H "Authorization: Bearer $LEARNLOOP_API_KEY" \
  -H "x-community-slug: $LL_SLUG" \
  -F "file=@/path/to/toolkit.pdf")
FILE_URL=$(echo "$UPLOAD" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['url'])")

# Then attach to product
ll POST /admin/products/$PRODUCT_ID/upload -d "{\"fileUrl\": \"$FILE_URL\"}"
```

### Publish / unpublish
```bash
ll POST /admin/products/$PRODUCT_ID/publish   # toggle
```

### Update cross-sell products
```bash
ll PATCH /admin/products/$PRODUCT_ID/cross-sell -d '{
  "crossSellProductIds": ["uuid-1", "uuid-2"]
}'
```

### Update funnel config (OTO, downsell)
```bash
ll PATCH /admin/products/$PRODUCT_ID/funnel -d '{
  "otoProductId": "uuid-oto",
  "downsellProductId": "uuid-downsell",
  "orderBumpProductId": "uuid-bump"
}'
```

### Delete a product
```bash
ll DELETE /admin/products/$PRODUCT_ID
```

---

## Storefront (public)

### List published products
```bash
ll_pub GET /products
```

### Get product detail
```bash
ll_pub GET /products/prompt-engineering-toolkit | python3 -m json.tool
```

---

## Checkout (public — simulate a purchase)

### Create a Stripe checkout session
```bash
PRODUCT_SLUG="prompt-engineering-toolkit"
RESULT=$(ll_pub POST /products/$PRODUCT_SLUG/checkout -d '{
  "quantity": 1,
  "discountCode": "EARLYBIRD"
}')
CHECKOUT_URL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['url'])")
echo "Checkout: $CHECKOUT_URL"
```

### Confirm purchase (called by Stripe success redirect)
```bash
SESSION_ID="cs_live_..."
ll_pub POST /products/checkout/confirm -d "{\"sessionId\": \"$SESSION_ID\"}"
```

### Get signed download URL (post-purchase)
```bash
PURCHASE_ID="..."
ll_pub GET /products/access/$PURCHASE_ID | python3 -c "
import sys, json
print(json.load(sys.stdin)['data']['downloadUrl'])
"
```

---

## Discounts (admin)

### List all discounts
```bash
ll GET /admin/discounts
```

### Create a discount code
```bash
ll POST /admin/discounts -d '{
  "code": "EARLYBIRD",
  "type": "percentage",
  "value": 20,
  "maxUses": 100,
  "expiresAt": "2026-06-01T00:00:00Z"
}'
```

`type` options: `"percentage"` | `"fixed_amount"`
`value`: percent (0–100) for percentage type, cents for fixed_amount.

### Create an auto-apply discount (no code needed)
```bash
ll POST /admin/discounts -d '{
  "type": "percentage",
  "value": 10,
  "autoApply": true,
  "description": "10% off for all members"
}'
```

### Update a discount
```bash
DISCOUNT_ID="..."
ll PATCH /admin/discounts/$DISCOUNT_ID -d '{ "maxUses": 500 }'
```

### Delete a discount
```bash
ll DELETE /admin/discounts/$DISCOUNT_ID
```

### Validate a code (public)
```bash
ll_pub POST /discounts/validate -d '{
  "code": "EARLYBIRD",
  "productId": "'$PRODUCT_ID'"
}'
```

---

## Gotchas

- `priceAmount` is always in cents. `2700` = $27.00. Stripe enforces a minimum of $0.50 (50 cents).
- Updating `priceAmount` on an existing product creates a new Stripe price and archives the old one — existing subscriptions are not affected.
- Fulfillment files are served via signed R2 URLs that expire after 24 hours — don't cache the URL.
- `autoApply: true` discounts are returned by `GET /discounts/auto-apply` and applied by the checkout UI automatically — no code needed from the buyer.
- Discount codes are case-insensitive on validation.
- Deleting a discount with `syncedToStripe: true` also archives it in Stripe.
