-- =============================================
-- UNIVERSAL E-COMMERCE PRODUCT MANAGEMENT SCHEMA
-- Supports: Shopify, Magento, WooCommerce, Drupal Commerce
-- Date: 2026-04-23
-- =============================================

USE [ProductManagementDB];
GO

-- =============================================
-- 1. CORE ENTITIES (Platform-Agnostic)
-- =============================================

-- 1.1 STORES/TENANTS (Multi-store support)
IF OBJECT_ID('dbo.Stores', 'U') IS NOT NULL
    DROP TABLE dbo.Stores;
GO

CREATE TABLE dbo.Stores (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(50) NOT NULL UNIQUE, -- 'us_store', 'eu_store', 'default'
    Name NVARCHAR(200) NOT NULL,
    Domain NVARCHAR(255) NULL,
    PlatformType NVARCHAR(50) NOT NULL, -- 'shopify', 'magento', 'woocommerce', 'drupal'
    PlatformVersion NVARCHAR(50) NULL,
    CurrencyCode NVARCHAR(3) DEFAULT 'USD',
    Timezone NVARCHAR(100) DEFAULT 'UTC',
    IsActive BIT DEFAULT 1,
    Config JSON NULL, -- Platform-specific store configuration
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- 1.2 TAXONOMY (Unified Category/Taxonomy system)
IF OBJECT_ID('dbo.TaxonomyTerms', 'U') IS NOT NULL
    DROP TABLE dbo.TaxonomyTerms;
GO

CREATE TABLE dbo.TaxonomyTerms (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    Vocabulary NVARCHAR(50) NOT NULL, -- 'category', 'collection', 'department', 'tag_group'
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    ParentId INT NULL,
    TermLevel INT DEFAULT 0, -- Depth in hierarchy
    TermPath NVARCHAR(MAX) NULL, -- Materialized path for fast queries (e.g., '1/5/12')
    DisplayOrder INT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    MetaTitle NVARCHAR(255) NULL,
    MetaDescription NVARCHAR(500) NULL,
    ImageUrl NVARCHAR(500) NULL,
    ExternalIds JSON NULL, -- Platform-specific IDs: {"magento": 123, "shopify": 456, "woo": 789}
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxonomyTerms_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT FK_TaxonomyTerms_Parent FOREIGN KEY (ParentId) REFERENCES dbo.TaxonomyTerms(Id),
    CONSTRAINT UQ_TaxonomyTerms_Store_Vocabulary_Slug UNIQUE (StoreId, Vocabulary, Slug)
);
GO

-- 1.3 BRANDS/MANUFACTURERS
IF OBJECT_ID('dbo.Brands', 'U') IS NOT NULL
    DROP TABLE dbo.Brands;
GO

CREATE TABLE dbo.Brands (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    Logo NVARCHAR(500) NULL,
    Website NVARCHAR(255) NULL,
    IsActive BIT DEFAULT 1,
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Brands_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT UQ_Brands_Store_Slug UNIQUE (StoreId, Slug)
);
GO

-- =============================================
-- 2. PRODUCT CORE
-- =============================================

-- 2.1 PRODUCT TYPES (Configurable/Simple/Grouped/Bundle)
IF OBJECT_ID('dbo.ProductTypes', 'U') IS NOT NULL
    DROP TABLE dbo.ProductTypes;
GO

CREATE TABLE dbo.ProductTypes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL UNIQUE, -- 'simple', 'configurable', 'grouped', 'bundle', 'virtual', 'downloadable'
    CanHaveVariants BIT DEFAULT 0,
    CanHaveChildren BIT DEFAULT 0,
    IsPhysical BIT DEFAULT 1,
    IsVirtual BIT DEFAULT 0
);
GO

INSERT INTO dbo.ProductTypes (Name, CanHaveVariants, CanHaveChildren, IsPhysical, IsVirtual)
VALUES 
    ('simple', 0, 0, 1, 0),
    ('configurable', 1, 0, 1, 0),
    ('grouped', 0, 1, 1, 0),
    ('bundle', 0, 1, 1, 0),
    ('virtual', 0, 0, 0, 1),
    ('downloadable', 0, 0, 0, 1);
GO

-- 2.2 MAIN PRODUCTS TABLE
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL
    DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    ProductTypeId INT NOT NULL,
    ParentProductId INT NULL, -- For grouped/bundle products
    Sku NVARCHAR(255) NOT NULL,
    Gtin NVARCHAR(50) NULL, -- GTIN/ISBN/UPC/MPN
    Name NVARCHAR(500) NOT NULL,
    Slug NVARCHAR(500) NOT NULL,
    ShortDescription NVARCHAR(1000) NULL,
    Description NVARCHAR(MAX) NULL,
    
    -- URLs
    UrlPath NVARCHAR(500) NULL,
    CanonicalUrl NVARCHAR(500) NULL,
    
    -- Status
    Status NVARCHAR(20) DEFAULT 'draft', -- draft, active, inactive, archived
    Visibility NVARCHAR(50) DEFAULT 'catalog_search', -- catalog, search, catalog_search, hidden
    IsFeatured BIT DEFAULT 0,
    IsInStock BIT DEFAULT 0,
    
    -- Dates
    PublishedAt DATETIME2 NULL,
    AvailableFrom DATETIME2 NULL,
    AvailableTo DATETIME2 NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    -- SEO
    MetaTitle NVARCHAR(255) NULL,
    MetaDescription NVARCHAR(500) NULL,
    MetaKeywords NVARCHAR(500) NULL,
    
    -- External IDs for platform sync
    ExternalIds JSON NULL,
    
    -- Custom attributes (JSON for flexible data)
    Attributes JSON NULL,
    
    CONSTRAINT FK_Products_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT FK_Products_ProductType FOREIGN KEY (ProductTypeId) REFERENCES dbo.ProductTypes(Id),
    CONSTRAINT FK_Products_ParentProduct FOREIGN KEY (ParentProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT UQ_Products_Store_Sku UNIQUE (StoreId, Sku),
    CONSTRAINT UQ_Products_Store_Slug UNIQUE (StoreId, Slug)
);
GO

-- 2.3 PRODUCT TAXONOMY MAPPING (Many-to-Many)
IF OBJECT_ID('dbo.ProductTaxonomyMappings', 'U') IS NOT NULL
    DROP TABLE dbo.ProductTaxonomyMappings;
GO

CREATE TABLE dbo.ProductTaxonomyMappings (
    ProductId INT NOT NULL,
    TermId INT NOT NULL,
    IsPrimary BIT DEFAULT 0,
    Position INT DEFAULT 0,
    
    CONSTRAINT PK_ProductTaxonomyMappings PRIMARY KEY (ProductId, TermId),
    CONSTRAINT FK_PTM_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PTM_Term FOREIGN KEY (TermId) REFERENCES dbo.TaxonomyTerms(Id) ON DELETE CASCADE
);
GO

-- 2.4 PRODUCT BRAND MAPPING
IF OBJECT_ID('dbo.ProductBrandMappings', 'U') IS NOT NULL
    DROP TABLE dbo.ProductBrandMappings;
GO

CREATE TABLE dbo.ProductBrandMappings (
    ProductId INT NOT NULL,
    BrandId INT NOT NULL,
    IsPrimary BIT DEFAULT 1,
    
    CONSTRAINT PK_ProductBrandMappings PRIMARY KEY (ProductId, BrandId),
    CONSTRAINT FK_PBM_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PBM_Brand FOREIGN KEY (BrandId) REFERENCES dbo.Brands(Id) ON DELETE CASCADE
);
GO

-- =============================================
-- 3. PRODUCT VARIANTS/OPTIONS SYSTEM (Generic)
-- =============================================

-- 3.1 ATTRIBUTES/OPTIONS (Platform-agnostic)
IF OBJECT_ID('dbo.Attributes', 'U') IS NOT NULL
    DROP TABLE dbo.Attributes;
GO

CREATE TABLE dbo.Attributes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    AttributeCode NVARCHAR(100) NOT NULL, -- 'color', 'size', 'material'
    AttributeType NVARCHAR(50) NOT NULL, -- 'text', 'select', 'multiselect', 'color', 'image', 'date', 'number'
    FrontendInput NVARCHAR(50) NOT NULL, -- 'select', 'multiselect', 'radiobutton', 'checkbox', 'swatch'
    Name NVARCHAR(200) NOT NULL,
    IsRequired BIT DEFAULT 0,
    IsVariantAttribute BIT DEFAULT 1, -- Used for product variations (Magento configurable, Shopify option)
    IsFilterable BIT DEFAULT 1,
    IsSearchable BIT DEFAULT 1,
    IsComparable BIT DEFAULT 0,
    DisplayOrder INT DEFAULT 0,
    DefaultValue NVARCHAR(255) NULL,
    ValidationRules JSON NULL, -- {'min': 0, 'max': 100, 'pattern': '^[A-Z]+$'}
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Attributes_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT UQ_Attributes_Store_Code UNIQUE (StoreId, AttributeCode)
);
GO

-- 3.2 ATTRIBUTE OPTIONS (Values)
IF OBJECT_ID('dbo.AttributeOptions', 'U') IS NOT NULL
    DROP TABLE dbo.AttributeOptions;
GO

CREATE TABLE dbo.AttributeOptions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AttributeId INT NOT NULL,
    OptionValue NVARCHAR(255) NOT NULL, -- 'Red', 'XL', 'Cotton'
    OptionSlug NVARCHAR(255) NOT NULL,
    SortOrder INT DEFAULT 0,
    IsDefault BIT DEFAULT 0,
    SwatchValue NVARCHAR(100) NULL, -- Hex color code (#FF0000) or image URL
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_AttributeOptions_Attribute FOREIGN KEY (AttributeId) REFERENCES dbo.Attributes(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_AttributeOptions_Attribute_Value UNIQUE (AttributeId, OptionValue)
);
GO

-- 3.3 PRODUCT ATTRIBUTE VALUES (For simple products)
IF OBJECT_ID('dbo.ProductAttributeValues', 'U') IS NOT NULL
    DROP TABLE dbo.ProductAttributeValues;
GO

CREATE TABLE dbo.ProductAttributeValues (
    ProductId INT NOT NULL,
    AttributeId INT NOT NULL,
    OptionId INT NULL, -- For select/multiselect
    ValueText NVARCHAR(MAX) NULL, -- For custom text inputs
    ValueDecimal DECIMAL(18,4) NULL, -- For number/price attributes
    ValueDate DATETIME2 NULL, -- For date attributes
    ValueBoolean BIT NULL, -- For boolean attributes
    
    CONSTRAINT PK_ProductAttributeValues PRIMARY KEY (ProductId, AttributeId),
    CONSTRAINT FK_PAV_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PAV_Attribute FOREIGN KEY (AttributeId) REFERENCES dbo.Attributes(Id),
    CONSTRAINT FK_PAV_Option FOREIGN KEY (OptionId) REFERENCES dbo.AttributeOptions(Id)
);
GO

-- =============================================
-- 4. VARIANTS (For configurable products)
-- =============================================

-- 4.1 VARIANT COMBINATIONS (Cartesian product of attribute options)
IF OBJECT_ID('dbo.Variants', 'U') IS NOT NULL
    DROP TABLE dbo.Variants;
GO

CREATE TABLE dbo.Variants (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL, -- Parent configurable product
    Sku NVARCHAR(255) NOT NULL,
    Gtin NVARCHAR(50) NULL,
    Name NVARCHAR(500) NOT NULL,
    IsDefault BIT DEFAULT 0,
    Status NVARCHAR(20) DEFAULT 'active',
    
    -- Pricing (can override parent)
    Price DECIMAL(18,4) NULL,
    CompareAtPrice DECIMAL(18,4) NULL,
    CostPrice DECIMAL(18,4) NULL,
    
    -- Inventory
    StockQuantity INT DEFAULT 0,
    BackorderAllowed BIT DEFAULT 0,
    MaxBackorder INT NULL,
    IsInStock BIT DEFAULT 0,
    
    -- Physical attributes
    Weight DECIMAL(18,4) NULL,
    WeightUnit NVARCHAR(10) DEFAULT 'kg', -- kg, g, lb, oz
    Length DECIMAL(18,4) NULL,
    Width DECIMAL(18,4) NULL,
    Height DECIMAL(18,4) NULL,
    DimensionUnit NVARCHAR(10) DEFAULT 'cm', -- cm, m, in, ft
    
    -- Shipping
    RequiresShipping BIT DEFAULT 1,
    FreeShipping BIT DEFAULT 0,
    
    -- Tax
    TaxClassId INT NULL,
    IsTaxable BIT DEFAULT 1,
    
    -- External IDs
    ExternalIds JSON NULL,
    
    Position INT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Variants_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_Variants_Product_Sku UNIQUE (ProductId, Sku),
    CONSTRAINT CK_Variants_Price CHECK (Price >= 0)
);
GO

-- 4.2 VARIANT ATTRIBUTE VALUES (Which combination this variant represents)
IF OBJECT_ID('dbo.VariantAttributeValues', 'U') IS NOT NULL
    DROP TABLE dbo.VariantAttributeValues;
GO

CREATE TABLE dbo.VariantAttributeValues (
    VariantId INT NOT NULL,
    AttributeId INT NOT NULL,
    OptionId INT NOT NULL,
    
    CONSTRAINT PK_VariantAttributeValues PRIMARY KEY (VariantId, AttributeId),
    CONSTRAINT FK_VAV_Variant FOREIGN KEY (VariantId) REFERENCES dbo.Variants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_VAV_Attribute FOREIGN KEY (AttributeId) REFERENCES dbo.Attributes(Id),
    CONSTRAINT FK_VAV_Option FOREIGN KEY (OptionId) REFERENCES dbo.AttributeOptions(Id)
);
GO

-- =============================================
-- 5. PRICING & DISCOUNTS (Flexible system)
-- =============================================

-- 5.1 PRICE RULES (Tier prices, special prices, etc.)
IF OBJECT_ID('dbo.PriceRules', 'U') IS NOT NULL
    DROP TABLE dbo.PriceRules;
GO

CREATE TABLE dbo.PriceRules (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    RuleType NVARCHAR(50) NOT NULL, -- 'tier_price', 'special_price', 'catalog_rule', 'cart_rule'
    Name NVARCHAR(255) NOT NULL,
    Priority INT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    
    -- Applicable entities
    ApplyTo NVARCHAR(20) DEFAULT 'all', -- 'all', 'specific', 'exclude'
    
    -- Conditions (JSON - flexible rule conditions)
    Conditions JSON NULL,
    
    -- Actions
    ActionType NVARCHAR(50) NOT NULL, -- 'fixed_amount', 'percentage', 'fixed_price'
    ActionValue DECIMAL(18,4) NOT NULL,
    
    -- Time constraints
    StartDate DATETIME2 NULL,
    EndDate DATETIME2 NULL,
    
    -- Usage limits
    UsageLimit INT NULL,
    UsedCount INT DEFAULT 0,
    
    CustomerGroups JSON NULL, -- Array of customer group IDs
    
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_PriceRules_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id)
);
GO

-- 5.2 PRICE RULE MAPPINGS (Specific products/variants)
IF OBJECT_ID('dbo.PriceRuleMappings', 'U') IS NOT NULL
    DROP TABLE dbo.PriceRuleMappings;
GO

CREATE TABLE dbo.PriceRuleMappings (
    PriceRuleId INT NOT NULL,
    ProductId INT NULL,
    VariantId INT NULL,
    
    CONSTRAINT PK_PriceRuleMappings PRIMARY KEY (PriceRuleId, ProductId, VariantId),
    CONSTRAINT FK_PRM_PriceRule FOREIGN KEY (PriceRuleId) REFERENCES dbo.PriceRules(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PRM_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_PRM_Variant FOREIGN KEY (VariantId) REFERENCES dbo.Variants(Id) ON DELETE CASCADE,
    CONSTRAINT CK_PRM_Target CHECK (ProductId IS NOT NULL OR VariantId IS NOT NULL)
);
GO

-- 5.3 TIER PRICES (Quantity-based pricing)
IF OBJECT_ID('dbo.TierPrices', 'U') IS NOT NULL
    DROP TABLE dbo.TierPrices;
GO

CREATE TABLE dbo.TierPrices (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NULL,
    VariantId INT NULL,
    CustomerGroupId INT NULL, -- For segmented pricing
    MinQuantity INT NOT NULL,
    Price DECIMAL(18,4) NOT NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TierPrices_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_TierPrices_Variant FOREIGN KEY (VariantId) REFERENCES dbo.Variants(Id) ON DELETE CASCADE,
    CONSTRAINT CK_TierPrices_Target CHECK (ProductId IS NOT NULL OR VariantId IS NOT NULL)
);
GO

-- =============================================
-- 6. INVENTORY SYSTEM (Multi-warehouse)
-- =============================================

-- 6.1 WAREHOUSES/LOCATIONS
IF OBJECT_ID('dbo.Warehouses', 'U') IS NOT NULL
    DROP TABLE dbo.Warehouses;
GO

CREATE TABLE dbo.Warehouses (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    Code NVARCHAR(50) NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    IsDefault BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    Address JSON NULL, -- Street, city, country, postal code
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Warehouses_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT UQ_Warehouses_Store_Code UNIQUE (StoreId, Code)
);
GO

-- 6.2 INVENTORY ITEMS (Stock by variant and warehouse)
IF OBJECT_ID('dbo.InventoryItems', 'U') IS NOT NULL
    DROP TABLE dbo.InventoryItems;
GO

CREATE TABLE dbo.InventoryItems (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    VariantId INT NOT NULL,
    WarehouseId INT NOT NULL,
    Quantity INT NOT NULL DEFAULT 0,
    ReservedQuantity INT NOT NULL DEFAULT 0, -- For pending orders
    AvailableQuantity AS (Quantity - ReservedQuantity) PERSISTED,
    MinStockThreshold INT NULL, -- Reorder point
    MaxStockThreshold INT NULL,
    ReorderQuantity INT NULL,
    ExpectedDelivery DATE NULL,
    LastStockTake DATETIME2 NULL,
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_InventoryItems_Variant FOREIGN KEY (VariantId) REFERENCES dbo.Variants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_InventoryItems_Warehouse FOREIGN KEY (WarehouseId) REFERENCES dbo.Warehouses(Id),
    CONSTRAINT UQ_InventoryItems_Variant_Warehouse UNIQUE (VariantId, WarehouseId),
    CONSTRAINT CK_InventoryItems_Quantity CHECK (Quantity >= 0 AND ReservedQuantity >= 0)
);
GO

-- =============================================
-- 7. MEDIA MANAGEMENT
-- =============================================

IF OBJECT_ID('dbo.Media', 'U') IS NOT NULL
    DROP TABLE dbo.Media;
GO

CREATE TABLE dbo.Media (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    EntityType NVARCHAR(50) NOT NULL, -- 'product', 'variant', 'category', 'brand'
    EntityId INT NOT NULL,
    MediaType NVARCHAR(50) NOT NULL, -- 'image', 'video', '3d_model', 'pdf'
    Url NVARCHAR(1000) NOT NULL,
    ThumbnailUrl NVARCHAR(1000) NULL,
    AltText NVARCHAR(255) NULL,
    Title NVARCHAR(255) NULL,
    Position INT DEFAULT 0,
    IsPrimary BIT DEFAULT 0,
    Metadata JSON NULL, -- width, height, size, duration, etc.
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_Media_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CREATE INDEX IX_Media_Entity ON dbo.Media(EntityType, EntityId)
);
GO

-- =============================================
-- 8. RELATIONSHIPS (Cross-sell, Up-sell, Related)
-- =============================================

IF OBJECT_ID('dbo.ProductRelations', 'U') IS NOT NULL
    DROP TABLE dbo.ProductRelations;
GO

CREATE TABLE dbo.ProductRelations (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    SourceProductId INT NOT NULL,
    TargetProductId INT NOT NULL,
    RelationType NVARCHAR(50) NOT NULL, -- 'related', 'cross_sell', 'up_sell', 'accessory', 'bundle'
    SortOrder INT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_PR_SourceProduct FOREIGN KEY (SourceProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT FK_PR_TargetProduct FOREIGN KEY (TargetProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT UQ_ProductRelations UNIQUE (SourceProductId, TargetProductId, RelationType)
);
GO

-- =============================================
-- 9. ATTRIBUTE SETS (Magento-like feature)
-- =============================================

IF OBJECT_ID('dbo.AttributeSets', 'U') IS NOT NULL
    DROP TABLE dbo.AttributeSets;
GO

CREATE TABLE dbo.AttributeSets (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    Name NVARCHAR(200) NOT NULL,
    BasedOn INT NULL, -- Clone from another set
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_AttributeSets_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id)
);
GO

IF OBJECT_ID('dbo.AttributeSetAttributes', 'U') IS NOT NULL
    DROP TABLE dbo.AttributeSetAttributes;
GO

CREATE TABLE dbo.AttributeSetAttributes (
    AttributeSetId INT NOT NULL,
    AttributeId INT NOT NULL,
    AttributeGroup NVARCHAR(100) NULL, -- 'Product Details', 'Shipping', 'SEO'
    SortOrder INT DEFAULT 0,
    IsRequired BIT DEFAULT 0,
    
    CONSTRAINT PK_AttributeSetAttributes PRIMARY KEY (AttributeSetId, AttributeId),
    CONSTRAINT FK_ASA_Set FOREIGN KEY (AttributeSetId) REFERENCES dbo.AttributeSets(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ASA_Attribute FOREIGN KEY (AttributeId) REFERENCES dbo.Attributes(Id) ON DELETE CASCADE
);
GO

-- 9.1 Product to Attribute Set mapping
ALTER TABLE dbo.Products ADD AttributeSetId INT NULL;
ALTER TABLE dbo.Products ADD CONSTRAINT FK_Products_AttributeSet FOREIGN KEY (AttributeSetId) REFERENCES dbo.AttributeSets(Id);
GO

-- =============================================
-- 10. REVISIONS & AUDIT (For versioning)
-- =============================================

IF OBJECT_ID('dbo.ProductRevisions', 'U') IS NOT NULL
    DROP TABLE dbo.ProductRevisions;
GO

CREATE TABLE dbo.ProductRevisions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    RevisionNumber INT NOT NULL,
    RevisionType NVARCHAR(50) DEFAULT 'auto', -- 'auto', 'manual', 'import'
    Snapshot JSON NOT NULL, -- Full product data snapshot
    CreatedBy NVARCHAR(255) NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    Comment NVARCHAR(500) NULL,
    
    CONSTRAINT FK_ProductRevisions_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_ProductRevisions_Product_Number UNIQUE (ProductId, RevisionNumber)
);
GO

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Products indexes
CREATE INDEX IX_Products_StoreId ON dbo.Products(StoreId);
CREATE INDEX IX_Products_ProductTypeId ON dbo.Products(ProductTypeId);
CREATE INDEX IX_Products_ParentProductId ON dbo.Products(ParentProductId);
CREATE INDEX IX_Products_Status ON dbo.Products(Status);
CREATE INDEX IX_Products_Sku ON dbo.Products(Sku);
CREATE INDEX IX_Products_Slug ON dbo.Products(Slug);
CREATE INDEX IX_Products_Visibility ON dbo.Products(Visibility);
CREATE INDEX IX_Products_PublishedAt ON dbo.Products(PublishedAt);

-- Variants indexes
CREATE INDEX IX_Variants_ProductId ON dbo.Variants(ProductId);
CREATE INDEX IX_Variants_Sku ON dbo.Variants(Sku);
CREATE INDEX IX_Variants_Status ON dbo.Variants(Status);
CREATE INDEX IX_Variants_IsDefault ON dbo.Variants(IsDefault);

-- Taxonomy indexes
CREATE INDEX IX_TaxonomyTerms_StoreId ON dbo.TaxonomyTerms(StoreId);
CREATE INDEX IX_TaxonomyTerms_ParentId ON dbo.TaxonomyTerms(ParentId);
CREATE INDEX IX_TaxonomyTerms_Vocabulary ON dbo.TaxonomyTerms(Vocabulary);
CREATE INDEX IX_TaxonomyTerms_TermPath ON dbo.TaxonomyTerms(TermPath);

-- Inventory indexes
CREATE INDEX IX_InventoryItems_VariantId ON dbo.InventoryItems(VariantId);
CREATE INDEX IX_InventoryItems_WarehouseId ON dbo.InventoryItems(WarehouseId);
CREATE INDEX IX_InventoryItems_AvailableQuantity ON dbo.InventoryItems(AvailableQuantity);

-- Price rules indexes
CREATE INDEX IX_PriceRules_StoreId ON dbo.PriceRules(StoreId);
CREATE INDEX IX_PriceRules_DateRange ON dbo.PriceRules(StartDate, EndDate) WHERE IsActive = 1;
CREATE INDEX IX_TierPrices_ProductId ON dbo.TierPrices(ProductId);
CREATE INDEX IX_TierPrices_VariantId ON dbo.TierPrices(VariantId);

-- JSON indexes (SQL Server 2016+ with JSON support)
CREATE INDEX IX_Products_ExternalIds ON dbo.Products(ExternalIds);
CREATE INDEX IX_Products_Attributes ON dbo.Products(Attributes);
CREATE INDEX IX_Products_ExternalIds_Key ON dbo.Products(JSON_VALUE(ExternalIds, '$.magento'));
GO

-- =============================================
-- HELPER FUNCTIONS & VIEWS
-- =============================================

-- View for getting active products with their current price
IF OBJECT_ID('dbo.vwActiveProducts', 'V') IS NOT NULL
    DROP VIEW dbo.vwActiveProducts;
GO

CREATE VIEW dbo.vwActiveProducts AS
SELECT 
    p.Id,
    p.StoreId,
    p.Sku,
    p.Name,
    p.Slug,
    p.Description,
    p.Status,
    p.IsFeatured,
    COALESCE(
        (SELECT TOP 1 Price FROM PriceRules pr 
         JOIN PriceRuleMappings prm ON pr.Id = prm.PriceRuleId 
         WHERE (prm.ProductId = p.Id OR prm.ProductId IS NULL)
         AND pr.IsActive = 1 AND pr.StartDate <= GETUTCDATE() 
         AND (pr.EndDate IS NULL OR pr.EndDate >= GETUTCDATE())
         ORDER BY pr.Priority),
        pv.Price,
        pv.Price
    ) AS CurrentPrice,
    p.CreatedAt,
    p.UpdatedAt
FROM Products p
LEFT JOIN Variants pv ON p.Id = pv.ProductId AND pv.IsDefault = 1
WHERE p.Status = 'active';
GO

-- Function to get product variant combination as string
IF OBJECT_ID('dbo.fn_GetVariantCombination', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetVariantCombination;
GO

CREATE FUNCTION dbo.fn_GetVariantCombination(@VariantId INT)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Combination NVARCHAR(MAX);
    
    SELECT @Combination = STRING_AGG(a.Name + ': ' + ao.OptionValue, ' | ')
    FROM VariantAttributeValues vav
    JOIN Attributes a ON vav.AttributeId = a.Id
    JOIN AttributeOptions ao ON vav.OptionId = ao.Id
    WHERE vav.VariantId = @VariantId;
    
    RETURN @Combination;
END;
GO

PRINT 'Universal e-commerce schema created successfully!';
PRINT 'Supports: Shopify, Magento, WooCommerce, Drupal Commerce';
GO
