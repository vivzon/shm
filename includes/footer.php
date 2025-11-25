
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            
            // --- Collapsible Sidebar Logic ---
            const submenuToggles = document.querySelectorAll('.sidebar .has-submenu > a');
            submenuToggles.forEach(toggle => {
                toggle.addEventListener('click', function(event) {
                    event.preventDefault();
                    this.parentElement.classList.toggle('open');
                });
            });
        });
    </script>
</body>
</html>