"""Business rules — the decisions the product makes, independent of HTTP.

Nothing here imports a router or touches a request. Routers translate HTTP into
calls on these, so a rule can be read, tested and changed in one place.

Named `domain` rather than `services` on purpose: in this product a "service" is
a vet or grooming visit (models.ServiceType), and routers/admin/services.py
already means that. Two senses of the word in one tree would be worse than a
slightly more formal package name.
"""
