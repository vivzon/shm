<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <title>Checkout - Vivzon</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>

<body class="bg-slate-900 text-white flex items-center justify-center h-screen">
    <div class="bg-slate-800 p-8 rounded-2xl shadow-2xl max-w-md w-full">
        <h2 class="text-2xl font-bold mb-6">Checkout</h2>
        <div class="mb-6 p-4 bg-slate-700/50 rounded-xl">
            <h3 class="font-bold text-lg">
                <?= $package['name'] ?>
            </h3>
            <p class="text-2xl font-bold text-blue-400">$
                <?= $package['price'] ?>/mo
            </p>
        </div>
        <form action="/checkout/process" method="POST" class="space-y-4">
            <input type="hidden" name="package_id" value="<?= $package['id'] ?>">
            <input name="email" type="email" placeholder="Email Address" required
                class="w-full bg-slate-900 p-3 rounded-xl border border-slate-600">
            <input name="card" placeholder="Card Number"
                class="w-full bg-slate-900 p-3 rounded-xl border border-slate-600">
            <div class="grid grid-cols-2 gap-4">
                <input name="expiry" placeholder="MM/YY"
                    class="w-full bg-slate-900 p-3 rounded-xl border border-slate-600">
                <input name="cvc" placeholder="CVC" class="w-full bg-slate-900 p-3 rounded-xl border border-slate-600">
            </div>
            <button type="submit" class="w-full bg-blue-600 hover:bg-blue-500 py-3 rounded-xl font-bold transition">Pay
                Now</button>
        </form>
    </div>
</body>

</html>