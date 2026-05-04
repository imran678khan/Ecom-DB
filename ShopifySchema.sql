-- =============================================
-- GENERIC PRODUCT MANAGEMENT EXTENSION
-- For Existing Database: ODB1
-- Supports: Shopify, WooCommerce, Magento, Custom Stores
-- Extends: Multi-tenant architecture (OnSellerId, GroupId, CompanyId, BranchId)
-- Date: 2026-05-04
-- =============================================

USE [ODB1];
GO

-- =============================================
-- 1. STORE CONFIGURATION (Multi-tenant, Multi-platform)
-- =============================================

IF OBJECT_ID('dbo.StoreConfigs', 'U') IS NOT NULL
    DROP TABLE dbo.StoreConfigs;
GO

CREATE TABLE dbo.StoreConfigs (
    StoreConfigId INT IDENTITY(1,1) PRIMARY KEY,
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Store Configuration
    StoreCode NVARCHAR(50) NOT NULL,
    StoreName NVARCHAR(200) NOT NULL,
    PlatformType NVARCHAR(50) NOT NULL, -- 'shopify', 'woocommerce', 'magento', 'custom'
    
    -- Platform Specific Configuration
    ApiUrl NVARCHAR(500) NULL,
    ApiKey NVARCHAR(500) NULL,
    ApiSecret NVARCHAR(500) NULL,
    AccessToken NVARCHAR(500) NULL,
    ApiVersion NVARCHAR(20) NULL,
    
    -- Store Settings
    DefaultCurrency NVARCHAR(3) DEFAULT 'USD',
    Timezone NVARCHAR(100) DEFAULT 'UTC',
    IsActive BIT NOT NULL DEFAULT 1,
    SyncEnabled BIT NOT NULL DEFAULT 1,
    AutoSyncInterval INT NULL, -- In minutes
    LastSyncAt DATETIME NULL,
    
    -- Webhook Settings
    WebhookSecret NVARCHAR(255) NULL,
    
    -- Configuration JSON (platform-specific settings)
    Config JSON NULL,
    
    -- Audit Fields
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_StoreConfigs_Company_Code UNIQUE (CompanyId, StoreCode),
    CONSTRAINT FK_StoreConfigs_Company FOREIGN KEY (CompanyId) REFERENCES dbo.Companies(CompanyId)
);
GO

-- =============================================
-- 2. PRODUCT CATEGORIES/COLLECTIONS
-- =============================================

IF OBJECT_ID('dbo.ProductCategories', 'U') IS NOT NULL
    DROP TABLE dbo.ProductCategories;
GO

CREATE TABLE dbo.ProductCategories (
    ProductCategoryId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Source IDs (for external platform sync)
    SourceCategoryId NVARCHAR(255) NULL, -- Platform's original ID
    SourcePlatform NVARCHAR(50) NULL, -- Which platform this came from
    
    Handle NVARCHAR(255) NOT NULL,
    Name NVARCHAR(500) NOT NULL,
    Description NVARCHAR(MAX) NULL,
    CategoryType NVARCHAR(50) DEFAULT 'manual', -- manual, smart, automatic
    
    -- Local Category Mapping
    DropDownDetailId INT NULL, -- Link to your existing category dropdown
    
    -- Sorting & Display
    SortOrder NVARCHAR(50) DEFAULT 'manual',
    ParentCategoryId INT NULL,
    CategoryLevel INT DEFAULT 0,
    CategoryPath NVARCHAR(MAX) NULL, -- Materialized path for hierarchy
    
    PublishedAt DATETIME NULL,
    
    -- SEO
    MetaTitle NVARCHAR(255) NULL,
    MetaDescription NVARCHAR(500) NULL,
    MetaKeywords NVARCHAR(500) NULL,
    
    -- Images
    ImageUrl NVARCHAR(1000) NULL,
    ImageAltText NVARCHAR(255) NULL,
    
    -- Smart Category Rules (JSON)
    Rules JSON NULL,
    Disjunctive BIT DEFAULT 0,
    
    -- Multi-tenant
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Status
    IsActive BIT NOT NULL DEFAULT 1,
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    LastSyncedAt DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ProductCategories_Store_Handle UNIQUE (StoreConfigId, Handle),
    CONSTRAINT UQ_ProductCategories_Store_Source UNIQUE (StoreConfigId, SourcePlatform, SourceCategoryId),
    CONSTRAINT FK_ProductCategories_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId),
    CONSTRAINT FK_ProductCategories_Parent FOREIGN KEY (ParentCategoryId) REFERENCES dbo.ProductCategories(ProductCategoryId)
);
GO

-- =============================================
-- 3. PRODUCTS MASTER
-- =============================================

IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL
    DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products (
    ProductId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Source IDs (for external platform sync)
    SourceProductId NVARCHAR(255) NULL, -- Platform's original product ID
    SourcePlatform NVARCHAR(50) NULL, -- Which platform this came from
    
    -- Basic Info
    Sku NVARCHAR(255) NOT NULL,
    Gtin NVARCHAR(50) NULL, -- GTIN/UPC/EAN/ISBN
    Name NVARCHAR(500) NOT NULL,
    Handle NVARCHAR(255) NOT NULL,
    ShortDescription NVARCHAR(1000) NULL,
    Description NVARCHAR(MAX) NULL,
    
    -- Product Type (links to DropdownDetails)
    ProductTypeId INT NULL, -- DropdownDetailId for product type
    Vendor NVARCHAR(255) NULL,
    BrandId INT NULL, -- If you have brands table
    
    -- URLs
    ProductUrl NVARCHAR(500) NULL,
    
    -- Status (matching your existing pattern)
    Status INT NOT NULL DEFAULT 1, -- 1: Draft, 2: Active, 3: Archived, 4: Discontinued
    Visibility NVARCHAR(50) DEFAULT 'catalog_search', -- catalog, search, catalog_search, hidden
    IsFeatured BIT NOT NULL DEFAULT 0,
    
    -- Publishing
    PublishedAt DATETIME NULL,
    AvailableFrom DATETIME NULL,
    AvailableTo DATETIME NULL,
    
    -- Template
    TemplateName NVARCHAR(100) NULL,
    
    -- SEO
    MetaTitle NVARCHAR(255) NULL,
    MetaDescription NVARCHAR(500) NULL,
    MetaKeywords NVARCHAR(500) NULL,
    
    -- Product Options (for configurable products)
    HasVariants BIT NOT NULL DEFAULT 0,
    VariantsCount INT NOT NULL DEFAULT 0,
    Option1Name NVARCHAR(100) NULL,
    Option2Name NVARCHAR(100) NULL,
    Option3Name NVARCHAR(100) NULL,
    
    -- Tags (JSON array for flexible tagging)
    Tags JSON NULL,
    
    -- Multi-tenant (matching your existing pattern)
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    DepartmentId INT NULL,
    
    -- Sync tracking
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    LastSyncedAt DATETIME NULL,
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Custom data
    Attributes JSON NULL, -- Flexible product attributes
    ExternalData JSON NULL, -- Raw source data storage
    Metadata JSON NULL, -- Additional metadata
    
    -- Audit fields
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_Products_Company_Sku UNIQUE (CompanyId, Sku),
    CONSTRAINT UQ_Products_Store_Handle UNIQUE (StoreConfigId, Handle),
    CONSTRAINT UQ_Products_Store_Source UNIQUE (StoreConfigId, SourcePlatform, SourceProductId),
    CONSTRAINT FK_Products_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId),
    CONSTRAINT FK_Products_Brand FOREIGN KEY (BrandId) REFERENCES dbo.DropdownDetails(DropDownDetailId)
);
GO

-- =============================================
-- 4. PRODUCT-CATEGORY MAPPING
-- =============================================

IF OBJECT_ID('dbo.ProductCategoryMappings', 'U') IS NOT NULL
    DROP TABLE dbo.ProductCategoryMappings;
GO

CREATE TABLE dbo.ProductCategoryMappings (
    ProductCategoryMappingId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    ProductCategoryId INT NOT NULL,
    IsPrimary BIT NOT NULL DEFAULT 0,
    Position INT DEFAULT 0,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_ProductCategoryMappings_Product_Category UNIQUE (ProductId, ProductCategoryId),
    CONSTRAINT FK_ProductCategoryMappings_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    CONSTRAINT FK_ProductCategoryMappings_Category FOREIGN KEY (ProductCategoryId) REFERENCES dbo.ProductCategories(ProductCategoryId) ON DELETE CASCADE
);
GO

-- =============================================
-- 5. PRODUCT VARIANTS
-- =============================================

IF OBJECT_ID('dbo.ProductVariants', 'U') IS NOT NULL
    DROP TABLE dbo.ProductVariants;
GO

CREATE TABLE dbo.ProductVariants (
    ProductVariantId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    
    -- Source IDs
    SourceVariantId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Basic Info
    Title NVARCHAR(500) NOT NULL,
    Sku NVARCHAR(255) NULL,
    Barcode NVARCHAR(255) NULL,
    Gtin NVARCHAR(50) NULL,
    
    -- Option Values (matching product options)
    Option1Value NVARCHAR(255) NULL,
    Option2Value NVARCHAR(255) NULL,
    Option3Value NVARCHAR(255) NULL,
    
    -- Pricing
    Price DECIMAL(18,2) NOT NULL DEFAULT 0,
    CompareAtPrice DECIMAL(18,2) NULL,
    CostPrice DECIMAL(18,2) NULL,
    Taxable BIT NOT NULL DEFAULT 1,
    TaxClassId INT NULL, -- Link to your tax configuration
    
    -- Inventory (Base - detailed inventory in separate table)
    StockQuantity INT NOT NULL DEFAULT 0,
    BackorderAllowed BIT NOT NULL DEFAULT 0,
    MaxBackorderQuantity INT NULL,
    LowStockThreshold INT NULL,
    
    -- Inventory Management
    InventoryPolicy NVARCHAR(20) DEFAULT 'deny', -- deny, continue
    InventoryManagement NVARCHAR(50) NULL, -- platform, external, manual
    InventoryItemId NVARCHAR(255) NULL, -- Platform's inventory item ID
    
    -- Shipping
    Weight DECIMAL(18,4) NULL,
    WeightUnit NVARCHAR(10) DEFAULT 'kg',
    Length DECIMAL(18,4) NULL,
    Width DECIMAL(18,4) NULL,
    Height DECIMAL(18,4) NULL,
    DimensionUnit NVARCHAR(10) DEFAULT 'cm',
    RequiresShipping BIT NOT NULL DEFAULT 1,
    FreeShipping BIT NOT NULL DEFAULT 0,
    
    -- Position & Default
    Position INT NOT NULL DEFAULT 0,
    IsDefault BIT NOT NULL DEFAULT 0,
    
    -- Fulfillment
    FulfillmentService NVARCHAR(100) DEFAULT 'manual',
    
    -- Status
    Status INT NOT NULL DEFAULT 1, -- 1: Active, 2: Archived, 3: Discontinued
    
    -- Sync tracking
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    LastSyncedAt DATETIME NULL,
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Custom attributes JSON
    Attributes JSON NULL,
    ExternalData JSON NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ProductVariants_Product_Sku UNIQUE (ProductId, Sku),
    CONSTRAINT UQ_ProductVariants_Product_Source UNIQUE (ProductId, SourcePlatform, SourceVariantId),
    CONSTRAINT FK_ProductVariants_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE
);
GO

-- =============================================
-- 6. INVENTORY (Multi-location - Extends/Integrates with your InventoryItems)
-- =============================================

IF OBJECT_ID('dbo.InventoryLocations', 'U') IS NOT NULL
    DROP TABLE dbo.InventoryLocations;
GO

CREATE TABLE dbo.InventoryLocations (
    InventoryLocationId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Source IDs
    SourceLocationId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Location Info
    LocationCode NVARCHAR(50) NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    
    -- Address (JSON for flexibility)
    Address JSON NULL,
    
    -- Link to your existing location
    LocationId INT NULL,
    
    -- Settings
    IsActive BIT NOT NULL DEFAULT 1,
    IsDefault BIT NOT NULL DEFAULT 0,
    IsPrimary BIT NOT NULL DEFAULT 0,
    
    -- Sync tracking
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_InventoryLocations_Store_Code UNIQUE (StoreConfigId, LocationCode),
    CONSTRAINT FK_InventoryLocations_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId),
    CONSTRAINT FK_InventoryLocations_Location FOREIGN KEY (LocationId) REFERENCES dbo.Locations(LocationId)
);
GO

IF OBJECT_ID('dbo.InventoryLevels', 'U') IS NOT NULL
    DROP TABLE dbo.InventoryLevels;
GO

CREATE TABLE dbo.InventoryLevels (
    InventoryLevelId INT IDENTITY(1,1) PRIMARY KEY,
    ProductVariantId INT NOT NULL,
    InventoryLocationId INT NOT NULL,
    
    -- Inventory quantities
    AvailableQuantity INT NOT NULL DEFAULT 0,
    OnHandQuantity INT NOT NULL DEFAULT 0,
    ReservedQuantity INT NOT NULL DEFAULT 0, -- For pending orders
    CommittedQuantity INT NOT NULL DEFAULT 0, -- For allocated orders
    IncomingQuantity INT NOT NULL DEFAULT 0, -- Expected from purchase orders
    
    -- Thresholds
    MinStockThreshold INT NULL, -- Reorder point
    MaxStockThreshold INT NULL,
    ReorderQuantity INT NULL,
    
    -- Tracking
    LastStockTakeDate DATETIME NULL,
    ExpectedDeliveryDate DATE NULL,
    
    -- Sync tracking
    UpdatedAtSource DATETIME NULL,
    LastSyncedAt DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_InventoryLevels_Variant_Location UNIQUE (ProductVariantId, InventoryLocationId),
    CONSTRAINT FK_InventoryLevels_Variant FOREIGN KEY (ProductVariantId) REFERENCES dbo.ProductVariants(ProductVariantId) ON DELETE CASCADE,
    CONSTRAINT FK_InventoryLevels_Location FOREIGN KEY (InventoryLocationId) REFERENCES dbo.InventoryLocations(InventoryLocationId)
);
GO

-- =============================================
-- 7. PRODUCT IMAGES
-- =============================================

IF OBJECT_ID('dbo.ProductImages', 'U') IS NOT NULL
    DROP TABLE dbo.ProductImages;
GO

CREATE TABLE dbo.ProductImages (
    ProductImageId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    ProductVariantId INT NULL,
    
    -- Source IDs
    SourceImageId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Image data
    ImageUrl NVARCHAR(1000) NOT NULL,
    ThumbnailUrl NVARCHAR(1000) NULL,
    AltText NVARCHAR(255) NULL,
    Title NVARCHAR(255) NULL,
    Width INT NULL,
    Height INT NULL,
    FileSize INT NULL, -- Size in bytes
    
    -- Link to your MediaLibrary
    MediaId INT NULL,
    
    -- Position
    Position INT NOT NULL DEFAULT 0,
    IsPrimary BIT NOT NULL DEFAULT 0,
    
    -- Variant IDs associated (JSON array)
    AssociatedVariantIds JSON NULL,
    
    -- Metadata
    Metadata JSON NULL,
    
    -- Sync tracking
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT FK_ProductImages_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    CONSTRAINT FK_ProductImages_Variant FOREIGN KEY (ProductVariantId) REFERENCES dbo.ProductVariants(ProductVariantId),
    CONSTRAINT FK_ProductImages_Media FOREIGN KEY (MediaId) REFERENCES dbo.MediaLibraries(MediaId)
);
GO

-- =============================================
-- 8. PRODUCT ATTRIBUTES (For variant attributes and custom fields)
-- =============================================

IF OBJECT_ID('dbo.ProductAttributes', 'U') IS NOT NULL
    DROP TABLE dbo.ProductAttributes;
GO

CREATE TABLE dbo.ProductAttributes (
    ProductAttributeId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Attribute Info
    AttributeCode NVARCHAR(100) NOT NULL,
    AttributeName NVARCHAR(200) NOT NULL,
    AttributeType NVARCHAR(50) NOT NULL, -- text, select, multiselect, color, image, date, number, boolean
    InputType NVARCHAR(50) NOT NULL, -- select, multiselect, radio, checkbox, swatch, text, textarea
    
    -- Settings
    IsRequired BIT NOT NULL DEFAULT 0,
    IsVariantAttribute BIT NOT NULL DEFAULT 0, -- Used for product variations
    IsFilterable BIT NOT NULL DEFAULT 1,
    IsSearchable BIT NOT NULL DEFAULT 1,
    IsComparable BIT NOT NULL DEFAULT 0,
    DisplayOrder INT NOT NULL DEFAULT 0,
    
    -- Default values
    DefaultValue NVARCHAR(255) NULL,
    
    -- Validation
    ValidationRules JSON NULL, -- min, max, pattern, etc.
    
    -- Multi-tenant
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Status
    IsActive BIT NOT NULL DEFAULT 1,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ProductAttributes_Store_Code UNIQUE (StoreConfigId, AttributeCode),
    CONSTRAINT FK_ProductAttributes_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId)
);
GO

IF OBJECT_ID('dbo.ProductAttributeOptions', 'U') IS NOT NULL
    DROP TABLE dbo.ProductAttributeOptions;
GO

CREATE TABLE dbo.ProductAttributeOptions (
    ProductAttributeOptionId INT IDENTITY(1,1) PRIMARY KEY,
    ProductAttributeId INT NOT NULL,
    
    OptionValue NVARCHAR(255) NOT NULL,
    OptionSlug NVARCHAR(255) NOT NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    IsDefault BIT NOT NULL DEFAULT 0,
    
    -- Visual representation
    SwatchValue NVARCHAR(100) NULL, -- Hex color code or image URL
    OptionImageUrl NVARCHAR(1000) NULL,
    
    -- External source IDs
    SourceOptionId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    CONSTRAINT UQ_ProductAttributeOptions_Attribute_Value UNIQUE (ProductAttributeId, OptionValue),
    CONSTRAINT FK_ProductAttributeOptions_Attribute FOREIGN KEY (ProductAttributeId) REFERENCES dbo.ProductAttributes(ProductAttributeId) ON DELETE CASCADE
);
GO

IF OBJECT_ID('dbo.ProductVariantAttributes', 'U') IS NOT NULL
    DROP TABLE dbo.ProductVariantAttributes;
GO

CREATE TABLE dbo.ProductVariantAttributes (
    ProductVariantId INT NOT NULL,
    ProductAttributeId INT NOT NULL,
    ProductAttributeOptionId INT NOT NULL,
    
    CONSTRAINT PK_ProductVariantAttributes PRIMARY KEY (ProductVariantId, ProductAttributeId),
    CONSTRAINT FK_ProductVariantAttributes_Variant FOREIGN KEY (ProductVariantId) REFERENCES dbo.ProductVariants(ProductVariantId) ON DELETE CASCADE,
    CONSTRAINT FK_ProductVariantAttributes_Attribute FOREIGN KEY (ProductAttributeId) REFERENCES dbo.ProductAttributes(ProductAttributeId),
    CONSTRAINT FK_ProductVariantAttributes_Option FOREIGN KEY (ProductAttributeOptionId) REFERENCES dbo.ProductAttributeOptions(ProductAttributeOptionId)
);
GO

-- =============================================
-- 9. PRODUCT ATTRIBUTE VALUES (For simple products without variants)
-- =============================================

IF OBJECT_ID('dbo.ProductAttributeValues', 'U') IS NOT NULL
    DROP TABLE dbo.ProductAttributeValues;
GO

CREATE TABLE dbo.ProductAttributeValues (
    ProductId INT NOT NULL,
    ProductAttributeId INT NOT NULL,
    ProductAttributeOptionId INT NULL, -- For select/multiselect
    ValueText NVARCHAR(MAX) NULL,
    ValueDecimal DECIMAL(18,4) NULL,
    ValueDate DATETIME NULL,
    ValueBoolean BIT NULL,
    ValueJson JSON NULL,
    
    CONSTRAINT PK_ProductAttributeValues PRIMARY KEY (ProductId, ProductAttributeId),
    CONSTRAINT FK_ProductAttributeValues_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    CONSTRAINT FK_ProductAttributeValues_Attribute FOREIGN KEY (ProductAttributeId) REFERENCES dbo.ProductAttributes(ProductAttributeId),
    CONSTRAINT FK_ProductAttributeValues_Option FOREIGN KEY (ProductAttributeOptionId) REFERENCES dbo.ProductAttributeOptions(ProductAttributeOptionId)
);
GO

-- =============================================
-- 10. PRICE RULES (Discounts, Special Prices, Tier Prices)
-- =============================================

IF OBJECT_ID('dbo.PriceRules', 'U') IS NOT NULL
    DROP TABLE dbo.PriceRules;
GO

CREATE TABLE dbo.PriceRules (
    PriceRuleId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Source IDs
    SourcePriceRuleId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Basic Info
    RuleCode NVARCHAR(100) NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    Description NVARCHAR(500) NULL,
    RuleType NVARCHAR(50) NOT NULL, -- 'tier_price', 'special_price', 'catalog_rule', 'cart_rule', 'discount_code'
    
    -- Target
    TargetType NVARCHAR(50) DEFAULT 'line_item', -- line_item, shipping_line, cart
    TargetSelection NVARCHAR(50) DEFAULT 'all', -- all, entitled
    
    -- Value
    ValueType NVARCHAR(50) NOT NULL, -- fixed_amount, percentage, fixed_price
    Value DECIMAL(18,4) NOT NULL,
    AllocationMethod NVARCHAR(50) DEFAULT 'each', -- each, across
    
    -- Customer eligibility
    CustomerSelection NVARCHAR(50) DEFAULT 'all', -- all, specific_groups, specific_users
    CustomerGroups JSON NULL, -- Array of customer group IDs
    CustomerIds JSON NULL, -- Array of user IDs
    
    -- Product eligibility
    ProductSelection NVARCHAR(50) DEFAULT 'all', -- all, specific, exclude
    ProductIds JSON NULL,
    CategoryIds JSON NULL,
    
    -- Time constraints
    StartDate DATETIME NULL,
    EndDate DATETIME NULL,
    
    -- Usage limits
    UsageLimit INT NULL,
    UsedCount INT NOT NULL DEFAULT 0,
    PerCustomerLimit INT NULL,
    
    -- Prerequisites
    MinimumSubtotal DECIMAL(18,4) NULL,
    MinimumQuantity INT NULL,
    PrerequisiteConditions JSON NULL,
    
    -- Priority
    Priority INT NOT NULL DEFAULT 0,
    
    -- Status
    Status INT NOT NULL DEFAULT 1, -- 1: Active, 2: Inactive, 3: Expired
    
    -- Multi-tenant
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Sync tracking
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_PriceRules_Store_Code UNIQUE (StoreConfigId, RuleCode),
    CONSTRAINT FK_PriceRules_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId)
);
GO

IF OBJECT_ID('dbo.PriceRuleMappings', 'U') IS NOT NULL
    DROP TABLE dbo.PriceRuleMappings;
GO

CREATE TABLE dbo.PriceRuleMappings (
    PriceRuleMappingId INT IDENTITY(1,1) PRIMARY KEY,
    PriceRuleId INT NOT NULL,
    ProductId INT NULL,
    ProductVariantId INT NULL,
    ProductCategoryId INT NULL,
    
    CONSTRAINT FK_PriceRuleMappings_Rule FOREIGN KEY (PriceRuleId) REFERENCES dbo.PriceRules(PriceRuleId) ON DELETE CASCADE,
    CONSTRAINT FK_PriceRuleMappings_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    CONSTRAINT FK_PriceRuleMappings_Variant FOREIGN KEY (ProductVariantId) REFERENCES dbo.ProductVariants(ProductVariantId) ON DELETE CASCADE,
    CONSTRAINT FK_PriceRuleMappings_Category FOREIGN KEY (ProductCategoryId) REFERENCES dbo.ProductCategories(ProductCategoryId) ON DELETE CASCADE,
    CONSTRAINT CK_PriceRuleMappings_Target CHECK (
        ProductId IS NOT NULL OR 
        ProductVariantId IS NOT NULL OR 
        ProductCategoryId IS NOT NULL
    )
);
GO

IF OBJECT_ID('dbo.TierPrices', 'U') IS NOT NULL
    DROP TABLE dbo.TierPrices;
GO

CREATE TABLE dbo.TierPrices (
    TierPriceId INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NULL,
    ProductVariantId INT NULL,
    CustomerGroupId INT NULL, -- Link to your customer groups (DropdownDetails)
    MinimumQuantity INT NOT NULL,
    Price DECIMAL(18,4) NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_TierPrices_Product FOREIGN KEY (ProductId) REFERENCES dbo.Products(ProductId) ON DELETE CASCADE,
    CONSTRAINT FK_TierPrices_Variant FOREIGN KEY (ProductVariantId) REFERENCES dbo.ProductVariants(ProductVariantId) ON DELETE CASCADE,
    CONSTRAINT CK_TierPrices_Target CHECK (ProductId IS NOT NULL OR ProductVariantId IS NOT NULL)
);
GO

-- =============================================
-- 11. DISCOUNT CODES
-- =============================================

IF OBJECT_ID('dbo.DiscountCodes', 'U') IS NOT NULL
    DROP TABLE dbo.DiscountCodes;
GO

CREATE TABLE dbo.DiscountCodes (
    DiscountCodeId INT IDENTITY(1,1) PRIMARY KEY,
    PriceRuleId INT NOT NULL,
    
    -- Source IDs
    SourceDiscountCodeId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Code Info
    Code NVARCHAR(255) NOT NULL,
    UsageCount INT NOT NULL DEFAULT 0,
    UsageLimitPerCode INT NULL,
    
    -- Sync tracking
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_DiscountCodes_PriceRule_Code UNIQUE (PriceRuleId, Code),
    CONSTRAINT FK_DiscountCodes_PriceRule FOREIGN KEY (PriceRuleId) REFERENCES dbo.PriceRules(PriceRuleId) ON DELETE CASCADE
);
GO

-- =============================================
-- 12. PRODUCT RELATIONSHIPS (Cross-sell, Up-sell, Related)
-- =============================================

IF OBJECT_ID('dbo.ProductRelations', 'U') IS NOT NULL
    DROP TABLE dbo.ProductRelations;
GO

CREATE TABLE dbo.ProductRelations (
    ProductRelationId INT IDENTITY(1,1) PRIMARY KEY,
    SourceProductId INT NOT NULL,
    TargetProductId INT NOT NULL,
    RelationType NVARCHAR(50) NOT NULL, -- 'related', 'cross_sell', 'up_sell', 'accessory', 'bundle'
    SortOrder INT NOT NULL DEFAULT 0,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_ProductRelations_Source_Target_Type UNIQUE (SourceProductId, TargetProductId, RelationType),
    CONSTRAINT FK_ProductRelations_SourceProduct FOREIGN KEY (SourceProductId) REFERENCES dbo.Products(ProductId),
    CONSTRAINT FK_ProductRelations_TargetProduct FOREIGN KEY (TargetProductId) REFERENCES dbo.Products(ProductId)
);
GO

-- =============================================
-- 13. METAFIELDS (Custom fields for product, variant, category)
-- =============================================

IF OBJECT_ID('dbo.Metafields', 'U') IS NOT NULL
    DROP TABLE dbo.Metafields;
GO

CREATE TABLE dbo.Metafields (
    MetafieldId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Owner Info (Polymorphic)
    OwnerType NVARCHAR(50) NOT NULL, -- 'product', 'variant', 'category'
    OwnerId INT NOT NULL, -- ID in respective table
    
    -- Source IDs
    SourceMetafieldId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Metafield Data
    Namespace NVARCHAR(255) NOT NULL,
    KeyName NVARCHAR(255) NOT NULL, -- 'Key' is reserved, using KeyName
    Value NVARCHAR(MAX) NOT NULL,
    ValueType NVARCHAR(50) DEFAULT 'string', -- string, integer, decimal, boolean, json, date
    
    -- Description
    Description NVARCHAR(500) NULL,
    
    -- Visibility
    IsVisible BIT NOT NULL DEFAULT 1,
    
    -- Sync tracking
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_Metafields_Store_Owner_Namespace_Key UNIQUE (StoreConfigId, OwnerType, OwnerId, Namespace, KeyName),
    CONSTRAINT FK_Metafields_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId)
);
GO

-- =============================================
-- 14. SYNC LOGS (Extending your AuditTrackings pattern)
-- =============================================

IF OBJECT_ID('dbo.SyncLogs', 'U') IS NOT NULL
    DROP TABLE dbo.SyncLogs;
GO

CREATE TABLE dbo.SyncLogs (
    SyncLogId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Sync Info
    EntityType NVARCHAR(50) NOT NULL, -- product, variant, category, order, inventory, price_rule
    EntityId INT NULL, -- Local entity ID
    SourceEntityId NVARCHAR(255) NULL, -- External platform entity ID
    
    SyncType NVARCHAR(50) NOT NULL, -- pull, push, webhook, import, export
    Direction NVARCHAR(20) NOT NULL, -- inbound, outbound, bidirectional
    Status NVARCHAR(50) NOT NULL, -- pending, processing, success, failed, partial
    
    -- Tracking
    RetryCount INT NOT NULL DEFAULT 0,
    RetryReason NVARCHAR(500) NULL,
    
    -- Data
    RequestData JSON NULL,
    ResponseData JSON NULL,
    ErrorMessage NVARCHAR(MAX) NULL,
    ErrorCode NVARCHAR(100) NULL,
    
    -- Statistics
    RecordsProcessed INT NULL,
    RecordsSucceeded INT NULL,
    RecordsFailed INT NULL,
    
    -- Timing
    StartedAt DATETIME NOT NULL DEFAULT GETDATE(),
    CompletedAt DATETIME NULL,
    
    -- Multi-tenant (matching your pattern)
    OnSellerId INT NULL,
    GroupId INT NULL,
    CompanyId INT NULL,
    BranchId INT NULL,
    
    -- Audit
    CreatedBy INT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_SyncLogs_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId)
);
GO

-- =============================================
-- 15. WEBHOOK REGISTRATIONS
-- =============================================

IF OBJECT_ID('dbo.WebhookRegistrations', 'U') IS NOT NULL
    DROP TABLE dbo.WebhookRegistrations;
GO

CREATE TABLE dbo.WebhookRegistrations (
    WebhookRegistrationId INT IDENTITY(1,1) PRIMARY KEY,
    StoreConfigId INT NOT NULL,
    
    -- Source IDs
    SourceWebhookId NVARCHAR(255) NULL,
    SourcePlatform NVARCHAR(50) NULL,
    
    -- Webhook Info
    Topic NVARCHAR(255) NOT NULL,
    Address NVARCHAR(1000) NOT NULL,
    Format NVARCHAR(50) NOT NULL DEFAULT 'json',
    ApiVersion NVARCHAR(20) NULL,
    
    -- Headers (JSON for custom headers)
    Headers JSON NULL,
    
    -- Status
    Status NVARCHAR(50) NOT NULL DEFAULT 'enabled', -- enabled, disabled, failed
    
    -- Filters (JSON for webhook filters)
    Filters JSON NULL,
    
    -- Statistics
    LastSuccessAt DATETIME NULL,
    LastFailureAt DATETIME NULL,
    FailureCount INT NOT NULL DEFAULT 0,
    SuccessCount INT NOT NULL DEFAULT 0,
    
    -- Sync tracking
    CreatedAtSource DATETIME NULL,
    UpdatedAtSource DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_WebhookRegistrations_Store_Topic UNIQUE (StoreConfigId, Topic),
    CONSTRAINT FK_WebhookRegistrations_StoreConfig FOREIGN KEY (StoreConfigId) REFERENCES dbo.StoreConfigs(StoreConfigId)
);
GO

-- =============================================
-- INDEXES (Matching your existing naming convention)
-- =============================================

-- Products
CREATE INDEX IX_Products_StoreConfig ON dbo.Products(StoreConfigId);
CREATE INDEX IX_Products_Sku ON dbo.Products(Sku);
CREATE INDEX IX_Products_Handle ON dbo.Products(Handle);
CREATE INDEX IX_Products_Status ON dbo.Products(Status);
CREATE INDEX IX_Products_Company ON dbo.Products(CompanyId, OnSellerId, GroupId);
CREATE INDEX IX_Products_SyncStatus ON dbo.Products(SyncStatus);
CREATE INDEX IX_Products_ProductType ON dbo.Products(ProductTypeId);
CREATE INDEX IX_Products_Brand ON dbo.Products(BrandId);
CREATE INDEX IX_Products_PublishedAt ON dbo.Products(PublishedAt);
CREATE INDEX IX_Products_Source ON dbo.Products(SourcePlatform, SourceProductId);

-- Product Variants
CREATE INDEX IX_ProductVariants_Product ON dbo.ProductVariants(ProductId);
CREATE INDEX IX_ProductVariants_Sku ON dbo.ProductVariants(Sku);
CREATE INDEX IX_ProductVariants_Barcode ON dbo.ProductVariants(Barcode);
CREATE INDEX IX_ProductVariants_Status ON dbo.ProductVariants(Status);
CREATE INDEX IX_ProductVariants_IsDefault ON dbo.ProductVariants(IsDefault);
CREATE INDEX IX_ProductVariants_Source ON dbo.ProductVariants(SourcePlatform, SourceVariantId);

-- Product Categories
CREATE INDEX IX_ProductCategories_StoreConfig ON dbo.ProductCategories(StoreConfigId);
CREATE INDEX IX_ProductCategories_Handle ON dbo.ProductCategories(Handle);
CREATE INDEX IX_ProductCategories_Parent ON dbo.ProductCategories(ParentCategoryId);
CREATE INDEX IX_ProductCategories_Company ON dbo.ProductCategories(CompanyId, OnSellerId, GroupId);
CREATE INDEX IX_ProductCategories_CategoryLevel ON dbo.ProductCategories(CategoryLevel);
CREATE INDEX IX_ProductCategories_CategoryPath ON dbo.ProductCategories(CategoryPath);

-- Product Category Mappings
CREATE INDEX IX_ProductCategoryMappings_Product ON dbo.ProductCategoryMappings(Product
