Key Features of This Universal Schema:
1. Multi-Platform Support
ExternalIds JSON column stores IDs from different platforms

PlatformType in Stores table identifies the source

Platform-specific configurations stored as JSON

2. Flexible Taxonomy System
Single TaxonomyTerms table handles categories, collections, departments

Vocabulary field distinguishes between different taxonomy types

Materialized path (TermPath) for fast hierarchical queries

3. Generic Variant System
Attributes define possible variations

Variants are combinations of attribute options

Works for Shopify (options), Magento (configurable), WooCommerce (variations)

4. Advanced Pricing
Tier prices (quantity-based)

Price rules with conditions (JSON-based rules engine)

Customer group pricing support

5. Multi-warehouse Inventory
Separate inventory tracking per warehouse

Reserved quantity for pending orders

Stock thresholds and reorder points

6. Media Management
Supports multiple media types (images, videos, 3D models)

Entity-agnostic (products, variants, categories, brands)

Position and primary flag

7. Attribute Sets (Magento-like)
Group attributes into logical sets

Different product types can use different attribute sets

8. Revisions & Audit Trail
Full JSON snapshots of product changes

Track who made changes and when

9. URL & SEO Support
Custom URL paths per store

Canonical URLs

Meta tags per entity

10. Platform Migration Ready
Store platform-specific data in ExternalIds

Easy to sync and migrate between platforms

JSON columns for platform-specific extensions
