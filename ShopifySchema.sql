-- =============================================
-- SHOPIFY PRODUCT MANAGEMENT EXTENSION
-- For Existing Database: ODB1
-- Extends: Multi-tenant architecture (OnSellerId, GroupId, CompanyId, BranchId)
-- Date: 2026-05-04
-- =============================================

USE [ODB1];
GO

-- =============================================
-- 1. SHOPIFY STORE CONFIGURATION (Multi-tenant)
-- =============================================

IF OBJECT_ID('dbo.ShopifyStoreConfigs', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyStoreConfigs;
GO

CREATE TABLE dbo.ShopifyStoreConfigs (
    ShopifyStoreConfigId INT IDENTITY(1,1) PRIMARY KEY,
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Shopify Configuration
    StoreName NVARCHAR(100) NOT NULL,
    ShopDomain NVARCHAR(255) NOT NULL,
    AccessToken NVARCHAR(500) NOT NULL,
    ApiVersion NVARCHAR(20) DEFAULT '2024-04',
    CurrencyCode NVARCHAR(3) DEFAULT 'USD',
    
    -- Store Settings
    IsActive BIT NOT NULL DEFAULT 1,
    SyncEnabled BIT NOT NULL DEFAULT 1,
    AutoSyncInterval INT NULL, -- In minutes
    LastSyncAt DATETIME NULL,
    
    -- Webhook Settings
    WebhookSecret NVARCHAR(255) NULL,
    
    -- Audit Fields (matching your existing pattern)
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ShopifyStoreConfigs_Domain UNIQUE (ShopDomain),
    CONSTRAINT UQ_ShopifyStoreConfigs_Company_StoreName UNIQUE (CompanyId, StoreName),
    CONSTRAINT FK_ShopifyStoreConfigs_Company FOREIGN KEY (CompanyId) REFERENCES dbo.Companies(CompanyId),
    CONSTRAINT FK_ShopifyStoreConfigs_Branch FOREIGN KEY (BranchId) REFERENCES dbo.Companies(CompanyId) -- Note: Assuming Branches are in Companies table with Type
);
GO

-- =============================================
-- 2. SHOPIFY PRODUCT CATEGORIES (Collections)
-- =============================================

IF OBJECT_ID('dbo.ShopifyCollections', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyCollections;
GO

CREATE TABLE dbo.ShopifyCollections (
    ShopifyCollectionId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Shopify Source IDs
    ShopifyCollectionSourceId BIGINT NOT NULL,
    Handle NVARCHAR(255) NOT NULL,
    Title NVARCHAR(500) NOT NULL,
    BodyHtml NVARCHAR(MAX) NULL,
    CollectionType NVARCHAR(50) DEFAULT 'custom', -- custom, smart
    
    -- Local Category Mapping (if needed)
    DropDownDetailId INT NULL, -- Link to your existing category dropdown
    
    -- Sorting & Display
    SortOrder NVARCHAR(50) DEFAULT 'manual',
    PublishedAt DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- SEO
    SeoTitle NVARCHAR(255) NULL,
    SeoDescription NVARCHAR(500) NULL,
    
    -- Image
    ImageSrc NVARCHAR(1000) NULL,
    ImageAltText NVARCHAR(255) NULL,
    
    -- Shopify Smart Collection Rules
    Rules JSON NULL,
    Disjunctive BIT DEFAULT 0,
    
    -- Multi-tenant (inherited from StoreConfig)
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Status
    IsActive BIT NOT NULL DEFAULT 1,
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ShopifyCollections_Store_ShopifyId UNIQUE (ShopifyStoreConfigId, ShopifyCollectionSourceId),
    CONSTRAINT UQ_ShopifyCollections_Store_Handle UNIQUE (ShopifyStoreConfigId, Handle),
    CONSTRAINT FK_ShopifyCollections_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId)
);
GO

-- =============================================
-- 3. SHOPIFY PRODUCTS MASTER
-- =============================================

IF OBJECT_ID('dbo.ShopifyProducts', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyProducts;
GO

CREATE TABLE dbo.ShopifyProducts (
    ShopifyProductId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Shopify Source IDs
    ShopifyProductSourceId BIGINT NOT NULL,
    Title NVARCHAR(500) NOT NULL,
    Handle NVARCHAR(255) NOT NULL,
    BodyHtml NVARCHAR(MAX) NULL,
    
    -- Product Type & Vendor (Links to your existing masters)
    Vendor NVARCHAR(255) NULL,
    ProductType NVARCHAR(255) NULL,
    DropDownDetailId INT NULL, -- Link to product type dropdown
    
    -- URLs
    ShopifyUrl NVARCHAR(500) NULL,
    
    -- Status (matching your existing pattern)
    Status INT NOT NULL DEFAULT 1, -- 1: Draft, 2: Active, 3: Archived
    PublishedScope NVARCHAR(50) DEFAULT 'global',
    PublishedAt DATETIME NULL,
    
    -- Template
    TemplateSuffix NVARCHAR(100) NULL,
    
    -- SEO (matching your existing Meta structure)
    MetaTitle NVARCHAR(255) NULL,
    MetaDescription NVARCHAR(500) NULL,
    MetaKeywords NVARCHAR(500) NULL,
    
    -- Shopify Tags (stored as JSON)
    Tags JSON NULL,
    
    -- Options (up to 3)
    Option1Name NVARCHAR(100) NULL,
    Option2Name NVARCHAR(100) NULL,
    Option3Name NVARCHAR(100) NULL,
    HasVariants BIT NOT NULL DEFAULT 0,
    VariantsCount INT NOT NULL DEFAULT 0,
    
    -- Multi-tenant (matching your existing pattern)
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    DepartmentId INT NULL,
    
    -- Sync tracking
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    LastSyncedAt DATETIME NULL,
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Custom attributes (JSON for flexible data - similar to your pattern)
    Attributes JSON NULL,
    ExternalData JSON NULL,
    
    -- Audit fields (matching your existing tables)
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ShopifyProducts_Store_ShopifyId UNIQUE (ShopifyStoreConfigId, ShopifyProductSourceId),
    CONSTRAINT UQ_ShopifyProducts_Store_Handle UNIQUE (ShopifyStoreConfigId, Handle),
    CONSTRAINT FK_ShopifyProducts_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId)
);
GO

-- =============================================
-- 4. SHOPIFY PRODUCT-COLLECTION MAPPING
-- =============================================

IF OBJECT_ID('dbo.ShopifyProductCollections', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyProductCollections;
GO

CREATE TABLE dbo.ShopifyProductCollections (
    ShopifyProductCollectionId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyProductId INT NOT NULL,
    ShopifyCollectionId INT NOT NULL,
    Position INT DEFAULT 0,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_ShopifyProductCollections_Product_Collection UNIQUE (ShopifyProductId, ShopifyCollectionId),
    CONSTRAINT FK_ShopifyProductCollections_Product FOREIGN KEY (ShopifyProductId) REFERENCES dbo.ShopifyProducts(ShopifyProductId) ON DELETE CASCADE,
    CONSTRAINT FK_ShopifyProductCollections_Collection FOREIGN KEY (ShopifyCollectionId) REFERENCES dbo.ShopifyCollections(ShopifyCollectionId) ON DELETE CASCADE
);
GO

-- =============================================
-- 5. SHOPIFY VARIANTS
-- =============================================

IF OBJECT_ID('dbo.ShopifyVariants', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyVariants;
GO

CREATE TABLE dbo.ShopifyVariants (
    ShopifyVariantId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyProductId INT NOT NULL,
    
    -- Shopify Source IDs
    ShopifyVariantSourceId BIGINT NOT NULL,
    Title NVARCHAR(500) NOT NULL,
    Sku NVARCHAR(255) NULL,
    Barcode NVARCHAR(255) NULL,
    
    -- Option Values
    Option1Value NVARCHAR(255) NULL,
    Option2Value NVARCHAR(255) NULL,
    Option3Value NVARCHAR(255) NULL,
    
    -- Pricing
    Price DECIMAL(18,2) NOT NULL DEFAULT 0,
    CompareAtPrice DECIMAL(18,2) NULL,
    Cost DECIMAL(18,2) NULL,
    Taxable BIT NOT NULL DEFAULT 1,
    
    -- Inventory (Base - detailed inventory in separate table)
    InventoryQuantity INT NOT NULL DEFAULT 0,
    InventoryPolicy NVARCHAR(20) DEFAULT 'deny',
    InventoryManagement NVARCHAR(50) NULL,
    InventoryItemId BIGINT NULL,
    
    -- Shipping
    Weight DECIMAL(18,4) NULL,
    WeightUnit NVARCHAR(10) DEFAULT 'kg',
    RequiresShipping BIT NOT NULL DEFAULT 1,
    
    -- Position & Default
    Position INT NOT NULL DEFAULT 0,
    IsDefault BIT NOT NULL DEFAULT 0,
    
    -- Fulfillment
    FulfillmentService NVARCHAR(100) DEFAULT 'manual',
    
    -- Status
    Status INT NOT NULL DEFAULT 1, -- 1: Active, 2: Archived
    
    -- Sync tracking
    SyncStatus NVARCHAR(50) DEFAULT 'synced',
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ShopifyVariants_Product_ShopifyId UNIQUE (ShopifyProductId, ShopifyVariantSourceId),
    CONSTRAINT UQ_ShopifyVariants_Product_Sku UNIQUE (ShopifyProductId, Sku),
    CONSTRAINT FK_ShopifyVariants_Product FOREIGN KEY (ShopifyProductId) REFERENCES dbo.ShopifyProducts(ShopifyProductId) ON DELETE CASCADE
);
GO

-- =============================================
-- 6. SHOPIFY INVENTORY (Multi-location - Extends your InventoryItems)
-- =============================================

IF OBJECT_ID('dbo.ShopifyLocations', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyLocations;
GO

CREATE TABLE dbo.ShopifyLocations (
    ShopifyLocationId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Shopify Source
    ShopifyLocationSourceId BIGINT NOT NULL,
    Name NVARCHAR(255) NOT NULL,
    
    -- Address (JSON for flexibility)
    Address JSON NULL,
    
    -- Link to your existing location (if applicable)
    LocationId INT NULL,
    
    IsActive BIT NOT NULL DEFAULT 1,
    IsPrimary BIT NOT NULL DEFAULT 0,
    
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT FK_ShopifyLocations_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId),
    CONSTRAINT FK_ShopifyLocations_Location FOREIGN KEY (LocationId) REFERENCES dbo.Locations(LocationId)
);
GO

IF OBJECT_ID('dbo.ShopifyInventoryLevels', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyInventoryLevels;
GO

CREATE TABLE dbo.ShopifyInventoryLevels (
    ShopifyInventoryLevelId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyVariantId INT NOT NULL,
    ShopifyLocationId INT NOT NULL,
    
    -- Inventory quantities
    AvailableQuantity INT NOT NULL DEFAULT 0,
    OnHandQuantity INT NOT NULL DEFAULT 0,
    ReservedQuantity INT NOT NULL DEFAULT 0,
    CommittedQuantity INT NOT NULL DEFAULT 0, -- For pending orders
    
    -- Sync tracking
    UpdatedAtShopify DATETIME NULL,
    LastSyncedAt DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT UQ_ShopifyInventoryLevels_Variant_Location UNIQUE (ShopifyVariantId, ShopifyLocationId),
    CONSTRAINT FK_ShopifyInventoryLevels_Variant FOREIGN KEY (ShopifyVariantId) REFERENCES dbo.ShopifyVariants(ShopifyVariantId) ON DELETE CASCADE,
    CONSTRAINT FK_ShopifyInventoryLevels_Location FOREIGN KEY (ShopifyLocationId) REFERENCES dbo.ShopifyLocations(ShopifyLocationId)
);
GO

-- =============================================
-- 7. SHOPIFY IMAGES
-- =============================================

IF OBJECT_ID('dbo.ShopifyImages', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyImages;
GO

CREATE TABLE dbo.ShopifyImages (
    ShopifyImageId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyProductId INT NOT NULL,
    ShopifyVariantId INT NULL,
    
    -- Shopify Source
    ShopifyImageSourceId BIGINT NOT NULL,
    Src NVARCHAR(1000) NOT NULL,
    AltText NVARCHAR(255) NULL,
    Width INT NULL,
    Height INT NULL,
    
    -- Link to your MediaLibrary
    MediaId INT NULL,
    
    -- Position
    Position INT NOT NULL DEFAULT 0,
    
    -- Variant IDs associated (JSON array)
    VariantIds JSON NULL,
    
    -- Sync
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_ShopifyImages_Product FOREIGN KEY (ShopifyProductId) REFERENCES dbo.ShopifyProducts(ShopifyProductId) ON DELETE CASCADE,
    CONSTRAINT FK_ShopifyImages_Variant FOREIGN KEY (ShopifyVariantId) REFERENCES dbo.ShopifyVariants(ShopifyVariantId),
    CONSTRAINT FK_ShopifyImages_Media FOREIGN KEY (MediaId) REFERENCES dbo.MediaLibraries(MediaId)
);
GO

-- =============================================
-- 8. SHOPIFY METAFIELDS (Custom fields)
-- =============================================

IF OBJECT_ID('dbo.ShopifyMetafields', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyMetafields;
GO

CREATE TABLE dbo.ShopifyMetafields (
    ShopifyMetafieldId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Owner Info
    OwnerResource NVARCHAR(50) NOT NULL, -- product, variant, collection
    OwnerId INT NOT NULL, -- ID in respective table
    
    -- Shopify Source
    ShopifyMetafieldSourceId BIGINT NOT NULL,
    Namespace NVARCHAR(255) NOT NULL,
    KeyName NVARCHAR(255) NOT NULL, -- 'Key' is reserved, using KeyName
    Value NVARCHAR(MAX) NOT NULL,
    ValueType NVARCHAR(50) DEFAULT 'string',
    Description NVARCHAR(500) NULL,
    
    -- Sync
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT UQ_ShopifyMetafields_Store_Owner_ShopifyId UNIQUE (ShopifyStoreConfigId, OwnerResource, OwnerId, ShopifyMetafieldSourceId),
    CONSTRAINT UQ_ShopifyMetafields_Store_Owner_Namespace_Key UNIQUE (ShopifyStoreConfigId, OwnerResource, OwnerId, Namespace, KeyName),
    CONSTRAINT FK_ShopifyMetafields_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId)
);
GO

-- =============================================
-- 9. SHOPIFY PRICE RULES (Discounts)
-- =============================================

IF OBJECT_ID('dbo.ShopifyPriceRules', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyPriceRules;
GO

CREATE TABLE dbo.ShopifyPriceRules (
    ShopifyPriceRuleId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Shopify Source
    ShopifyPriceRuleSourceId BIGINT NOT NULL,
    Title NVARCHAR(255) NOT NULL,
    TargetType NVARCHAR(50) DEFAULT 'line_item',
    TargetSelection NVARCHAR(50) DEFAULT 'all',
    AllocationMethod NVARCHAR(50) DEFAULT 'each',
    ValueType NVARCHAR(50) NOT NULL, -- fixed_amount, percentage
    Value DECIMAL(18,4) NOT NULL,
    
    -- Customer eligibility
    CustomerSelection NVARCHAR(50) DEFAULT 'all',
    CustomerIds JSON NULL,
    
    -- Time constraints
    StartsAt DATETIME NULL,
    EndsAt DATETIME NULL,
    
    -- Usage limits
    UsageLimit INT NULL,
    UsedCount INT NOT NULL DEFAULT 0,
    
    -- Prerequisite conditions
    PrerequisiteConditions JSON NULL,
    Entitlement JSON NULL,
    
    -- Status
    Status INT NOT NULL DEFAULT 1, -- 1: Active, 2: Inactive
    
    -- Multi-tenant
    OnSellerId INT NOT NULL,
    GroupId INT NOT NULL,
    CompanyId INT NOT NULL,
    BranchId INT NULL,
    
    -- Sync
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT FK_ShopifyPriceRules_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId)
);
GO

IF OBJECT_ID('dbo.ShopifyDiscountCodes', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyDiscountCodes;
GO

CREATE TABLE dbo.ShopifyDiscountCodes (
    ShopifyDiscountCodeId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyPriceRuleId INT NOT NULL,
    
    -- Shopify Source
    ShopifyDiscountCodeSourceId BIGINT NOT NULL,
    Code NVARCHAR(255) NOT NULL,
    UsageCount INT NOT NULL DEFAULT 0,
    
    -- Sync
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_ShopifyDiscountCodes_PriceRule FOREIGN KEY (ShopifyPriceRuleId) REFERENCES dbo.ShopifyPriceRules(ShopifyPriceRuleId) ON DELETE CASCADE,
    CONSTRAINT UQ_ShopifyDiscountCodes_PriceRule_Code UNIQUE (ShopifyPriceRuleId, Code)
);
GO

-- =============================================
-- 10. SHOPIFY ORDERS (Integration with your Purchase Orders)
-- =============================================

IF OBJECT_ID('dbo.ShopifyOrders', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyOrders;
GO

CREATE TABLE dbo.ShopifyOrders (
    ShopifyOrderId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Shopify Source
    ShopifyOrderSourceId BIGINT NOT NULL,
    OrderNumber NVARCHAR(50) NOT NULL,
    Name NVARCHAR(100) NOT NULL,
    
    -- Customer Info
    CustomerEmail NVARCHAR(255) NULL,
    CustomerFirstName NVARCHAR(100) NULL,
    CustomerLastName NVARCHAR(100) NULL,
    
    -- Order Details
    FinancialStatus NVARCHAR(50) NULL,
    FulfillmentStatus NVARCHAR(50) NULL,
    TotalPrice DECIMAL(18,2) NOT NULL,
    SubtotalPrice DECIMAL(18,2) NOT NULL,
    TotalTax DECIMAL(18,2) NOT NULL,
    Currency NVARCHAR(3) NOT NULL,
    
    -- Dates
    OrderDate DATETIME NOT NULL,
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    
    -- Link to your Purchase Order (if applicable)
    PurchaseOrderId UNIQUEIDENTIFIER NULL,
    
    -- Order Data (full JSON from Shopify)
    OrderData JSON NULL,
    
    -- Sync
    IsProcessed BIT NOT NULL DEFAULT 0,
    ProcessedDate DATETIME NULL,
    
    -- Audit
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    ModifiedBy INT NULL,
    ModifiedDate DATETIME NULL,
    
    CONSTRAINT FK_ShopifyOrders_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId),
    CONSTRAINT FK_ShopifyOrders_PurchaseOrder FOREIGN KEY (PurchaseOrderId) REFERENCES dbo.PurchaseOrders(Id)
);
GO

IF OBJECT_ID('dbo.ShopifyOrderItems', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyOrderItems;
GO

CREATE TABLE dbo.ShopifyOrderItems (
    ShopifyOrderItemId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyOrderId INT NOT NULL,
    ShopifyVariantId INT NOT NULL,
    
    -- Product Info at time of order
    ProductTitle NVARCHAR(500) NOT NULL,
    VariantTitle NVARCHAR(500) NOT NULL,
    Sku NVARCHAR(255) NULL,
    
    -- Quantity & Price
    Quantity INT NOT NULL,
    Price DECIMAL(18,2) NOT NULL,
    TotalDiscount DECIMAL(18,2) NOT NULL DEFAULT 0,
    
    -- Link to PO Item (if applicable)
    POItemId UNIQUEIDENTIFIER NULL,
    
    -- Audit
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_ShopifyOrderItems_Order FOREIGN KEY (ShopifyOrderId) REFERENCES dbo.ShopifyOrders(ShopifyOrderId) ON DELETE CASCADE,
    CONSTRAINT FK_ShopifyOrderItems_Variant FOREIGN KEY (ShopifyVariantId) REFERENCES dbo.ShopifyVariants(ShopifyVariantId),
    CONSTRAINT FK_ShopifyOrderItems_POItem FOREIGN KEY (POItemId) REFERENCES dbo.POItems(Id)
);
GO

-- =============================================
-- 11. SYNC LOGS (Extending your AuditTrackings pattern)
-- =============================================

IF OBJECT_ID('dbo.ShopifySyncLogs', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifySyncLogs;
GO

CREATE TABLE dbo.ShopifySyncLogs (
    ShopifySyncLogId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Sync Info
    EntityType NVARCHAR(50) NOT NULL, -- product, variant, collection, order, inventory
    EntityId INT NULL, -- Local entity ID
    ShopifyEntityId BIGINT NULL,
    
    SyncType NVARCHAR(50) NOT NULL, -- pull, push, webhook
    Status NVARCHAR(50) NOT NULL, -- success, failed, pending, processing
    RetryCount INT NOT NULL DEFAULT 0,
    
    -- Data
    RequestData JSON NULL,
    ResponseData JSON NULL,
    ErrorMessage NVARCHAR(MAX) NULL,
    
    -- Timing
    StartedAt DATETIME NOT NULL DEFAULT GETDATE(),
    CompletedAt DATETIME NULL,
    
    -- Multi-tenant (matching your pattern)
    OnSellerId INT NULL,
    GroupId INT NULL,
    CompanyId INT NULL,
    BranchId INT NULL,
    
    CONSTRAINT FK_ShopifySyncLogs_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId)
);
GO

-- =============================================
-- 12. WEBHOOK REGISTRATIONS
-- =============================================

IF OBJECT_ID('dbo.ShopifyWebhooks', 'U') IS NOT NULL
    DROP TABLE dbo.ShopifyWebhooks;
GO

CREATE TABLE dbo.ShopifyWebhooks (
    ShopifyWebhookId INT IDENTITY(1,1) PRIMARY KEY,
    ShopifyStoreConfigId INT NOT NULL,
    
    -- Webhook Info
    Topic NVARCHAR(255) NOT NULL,
    Address NVARCHAR(1000) NOT NULL,
    Format NVARCHAR(50) NOT NULL DEFAULT 'json',
    
    -- Shopify Source
    ShopifyWebhookSourceId BIGINT NOT NULL,
    
    -- Status
    Status NVARCHAR(50) NOT NULL DEFAULT 'enabled',
    
    -- Stats
    LastSuccessAt DATETIME NULL,
    LastFailureAt DATETIME NULL,
    FailureCount INT NOT NULL DEFAULT 0,
    
    -- Audit
    CreatedAtShopify DATETIME NULL,
    UpdatedAtShopify DATETIME NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE(),
    
    CONSTRAINT FK_ShopifyWebhooks_StoreConfig FOREIGN KEY (ShopifyStoreConfigId) REFERENCES dbo.ShopifyStoreConfigs(ShopifyStoreConfigId),
    CONSTRAINT UQ_ShopifyWebhooks_Store_Topic UNIQUE (ShopifyStoreConfigId, Topic)
);
GO

-- =============================================
-- INDEXES (Matching your existing naming convention)
-- =============================================

-- Shopify Products
CREATE INDEX IX_ShopifyProducts_StoreConfig ON dbo.ShopifyProducts(ShopifyStoreConfigId);
CREATE INDEX IX_ShopifyProducts_Handle ON dbo.ShopifyProducts(Handle);
CREATE INDEX IX_ShopifyProducts_Status ON dbo.ShopifyProducts(Status);
CREATE INDEX IX_ShopifyProducts_Company ON dbo.ShopifyProducts(CompanyId, OnSellerId, GroupId);
CREATE INDEX IX_ShopifyProducts_SyncStatus ON dbo.ShopifyProducts(SyncStatus);

-- Shopify Variants
CREATE INDEX IX_ShopifyVariants_Product ON dbo.ShopifyVariants(ShopifyProductId);
CREATE INDEX IX_ShopifyVariants_Sku ON dbo.ShopifyVariants(Sku);
CREATE INDEX IX_ShopifyVariants_Barcode ON dbo.ShopifyVariants(Barcode);
CREATE INDEX IX_ShopifyVariants_Status ON dbo.ShopifyVariants(Status);

-- Shopify Collections
CREATE INDEX IX_ShopifyCollections_StoreConfig ON dbo.ShopifyCollections(ShopifyStoreConfigId);
CREATE INDEX IX_ShopifyCollections_Handle ON dbo.ShopifyCollections(Handle);
CREATE INDEX IX_ShopifyCollections_Company ON dbo.ShopifyCollections(CompanyId, OnSellerId, GroupId);

-- Inventory Levels
CREATE INDEX IX_ShopifyInventoryLevels_Variant ON dbo.ShopifyInventoryLevels(ShopifyVariantId);
CREATE INDEX IX_ShopifyInventoryLevels_Location ON dbo.ShopifyInventoryLevels(ShopifyLocationId);
CREATE INDEX IX_ShopifyInventoryLevels_Available ON dbo.ShopifyInventoryLevels(AvailableQuantity);

-- Shopify Orders
CREATE INDEX IX_ShopifyOrders_StoreConfig ON dbo.ShopifyOrders(ShopifyStoreConfigId);
CREATE INDEX IX_ShopifyOrders_OrderNumber ON dbo.ShopifyOrders(OrderNumber);
CREATE INDEX IX_ShopifyOrders_Dates ON dbo.ShopifyOrders(OrderDate, CreatedDate);
CREATE INDEX IX_ShopifyOrders_PurchaseOrder ON dbo.ShopifyOrders(PurchaseOrderId);

-- Shopify Order Items
CREATE INDEX IX_ShopifyOrderItems_Order ON dbo.ShopifyOrderItems(ShopifyOrderId);
CREATE INDEX IX_ShopifyOrderItems_Variant ON dbo.ShopifyOrderItems(ShopifyVariantId);
CREATE INDEX IX_ShopifyOrderItems_POItem ON dbo.ShopifyOrderItems(POItemId);

-- Shopify Images
CREATE INDEX IX_ShopifyImages_Product ON dbo.ShopifyImages(ShopifyProductId);
CREATE INDEX IX_ShopifyImages_Variant ON dbo.ShopifyImages(ShopifyVariantId);
CREATE INDEX IX_ShopifyImages_Position ON dbo.ShopifyImages(Position);

-- Shopify Metafields
CREATE INDEX IX_ShopifyMetafields_Owner ON dbo.ShopifyMetafields(OwnerResource, OwnerId);
CREATE INDEX IX_ShopifyMetafields_Namespace_Key ON dbo.ShopifyMetafields(Namespace, KeyName);
CREATE INDEX IX_ShopifyMetafields_StoreConfig ON dbo.ShopifyMetafields(ShopifyStoreConfigId);

-- Sync Logs (matching your AuditTrackings pattern)
CREATE INDEX IX_ShopifySyncLogs_StoreConfig ON dbo.ShopifySyncLogs(ShopifyStoreConfigId);
CREATE INDEX IX_ShopifySyncLogs_Entity ON dbo.ShopifySyncLogs(EntityType, EntityId);
CREATE INDEX IX_ShopifySyncLogs_Status ON dbo.ShopifySyncLogs(Status);
CREATE INDEX IX_ShopifySyncLogs_CreatedAt ON dbo.ShopifySyncLogs(StartedAt);

-- JSON indexes (for SQL Server 2016+)
CREATE INDEX IX_ShopifyProducts_Tags ON dbo.ShopifyProducts(Tags);
CREATE INDEX IX_ShopifyProducts_Attributes ON dbo.ShopifyProducts(Attributes);
GO

-- =============================================
-- HELPER VIEWS
-- =============================================

-- View: Product inventory summary (matching existing pattern)
IF OBJECT_ID('dbo.vw_ShopifyProductInventory', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ShopifyProductInventory;
GO

CREATE VIEW dbo.vw_ShopifyProductInventory AS
SELECT 
    p.ShopifyProductId,
    p.Title,
    p.Handle,
    p.Sku,
    p.HasVariants,
    COUNT(DISTINCT v.ShopifyVariantId) AS VariantCount,
    SUM(COALESCE(il.AvailableQuantity, v.InventoryQuantity)) AS TotalAvailableInventory,
    MIN(v.Price) AS MinPrice,
    MAX(v.Price) AS MaxPrice,
    MIN(CASE WHEN v.IsDefault = 1 THEN v.Price END) AS DefaultPrice,
    p.Status,
    p.CompanyId,
    p.OnSellerId,
    p.GroupId
FROM dbo.ShopifyProducts p
LEFT JOIN dbo.ShopifyVariants v ON p.ShopifyProductId = v.ShopifyProductId AND v.Status = 1
LEFT JOIN dbo.ShopifyInventoryLevels il ON v.ShopifyVariantId = il.ShopifyVariantId
WHERE p.Status = 1
GROUP BY p.ShopifyProductId, p.Title, p.Handle, p.Sku, p.HasVariants, p.Status, p.CompanyId, p.OnSellerId, p.GroupId;
GO

-- View: Products by Company (multi-tenant)
IF OBJECT_ID('dbo.vw_ShopifyProductsByCompany', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ShopifyProductsByCompany;
GO

CREATE VIEW dbo.vw_ShopifyProductsByCompany AS
SELECT 
    p.*,
    c.Name AS CompanyName,
    s.StoreName,
    s.ShopDomain
FROM dbo.ShopifyProducts p
INNER JOIN dbo.Companies c ON p.CompanyId = c.CompanyId
INNER JOIN dbo.ShopifyStoreConfigs s ON p.ShopifyStoreConfigId = s.ShopifyStoreConfigId;
GO

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- SP: Sync product from Shopify
IF OBJECT_ID('dbo.sp_Shopify_SyncProduct', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Shopify_SyncProduct;
GO

CREATE PROCEDURE dbo.sp_Shopify_SyncProduct
    @StoreConfigId INT,
    @ShopifyProductId BIGINT,
    @ProductData JSON,
    @UserId INT,
    @SyncLogId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Create sync log (matching AuditTrackings pattern)
        INSERT INTO dbo.ShopifySyncLogs (
            ShopifyStoreConfigId, EntityType, ShopifyEntityId, SyncType, 
            Status, RequestData, StartedAt, CreatedBy
        )
        VALUES (
            @StoreConfigId, 'product', @ShopifyProductId, 'pull',
            'processing', @ProductData, GETDATE(), @UserId
        );
        
        SET @SyncLogId = SCOPE_IDENTITY();
        
        -- Extract store config to get multi-tenant IDs
        DECLARE @OnSellerId INT, @GroupId INT, @CompanyId INT, @BranchId INT;
        
        SELECT 
            @OnSellerId = OnSellerId,
            @GroupId = GroupId,
            @CompanyId = CompanyId,
            @BranchId = BranchId
        FROM dbo.ShopifyStoreConfigs
        WHERE ShopifyStoreConfigId = @StoreConfigId;
        
        -- Extract product data from JSON
        DECLARE @Title NVARCHAR(500) = JSON_VALUE(@ProductData, '$.title');
        DECLARE @Handle NVARCHAR(255) = JSON_VALUE(@ProductData, '$.handle');
        DECLARE @BodyHtml NVARCHAR(MAX) = JSON_VALUE(@ProductData, '$.body_html');
        DECLARE @Vendor NVARCHAR(255) = JSON_VALUE(@ProductData, '$.vendor');
        DECLARE @ProductType NVARCHAR(255) = JSON_VALUE(@ProductData, '$.product_type');
        DECLARE @Status NVARCHAR(50) = JSON_VALUE(@ProductData, '$.status');
        DECLARE @PublishedAt DATETIME = JSON_VALUE(@ProductData, '$.published_at');
        DECLARE @Tags NVARCHAR(MAX) = JSON_QUERY(@ProductData, '$.tags');
        DECLARE @Option1Name NVARCHAR(100) = JSON_VALUE(@ProductData, '$.options[0].name');
        DECLARE @Option2Name NVARCHAR(100) = JSON_VALUE(@ProductData, '$.options[1].name');
        DECLARE @Option3Name NVARCHAR(100) = JSON_VALUE(@ProductData, '$.options[2].name');
        
        -- UPSERT product
        MERGE dbo.ShopifyProducts AS target
        USING (SELECT @StoreConfigId AS ShopifyStoreConfigId, @ShopifyProductId AS ShopifyProductSourceId) AS source
        ON target.ShopifyStoreConfigId = source.ShopifyStoreConfigId 
           AND target.ShopifyProductSourceId = source.ShopifyProductSourceId
        WHEN MATCHED THEN
            UPDATE SET 
                Title = @Title,
                Handle = @Handle,
                BodyHtml = @BodyHtml,
                Vendor = @Vendor,
                ProductType = @ProductType,
                Status = CASE WHEN @Status = 'active' THEN 1 ELSE 2 END,
                PublishedAt = @PublishedAt,
                Tags = @Tags,
                Option1Name = @Option1Name,
                Option2Name = @Option2Name,
                Option3Name = @Option3Name,
                UpdatedAtShopify = GETDATE(),
                ModifiedDate = GETDATE(),
                ModifiedBy = @UserId,
                ExternalData = @ProductData,
                SyncStatus = 'synced',
                LastSyncedAt = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (
                ShopifyStoreConfigId, ShopifyProductSourceId, Title, Handle, BodyHtml, 
                Vendor, ProductType, Status, PublishedAt, Tags, Option1Name, Option2Name, 
                Option3Name, OnSellerId, GroupId, CompanyId, BranchId, CreatedBy, 
                CreatedDate, CreatedAtShopify, ExternalData, SyncStatus, LastSyncedAt
            )
            VALUES (
                @StoreConfigId, @ShopifyProductId, @Title, @Handle, @BodyHtml,
                @Vendor, @ProductType, CASE WHEN @Status = 'active' THEN 1 ELSE 2 END, 
                @PublishedAt, @Tags, @Option1Name, @Option2Name, @Option3Name,
                @OnSellerId, @GroupId, @CompanyId, @BranchId, @UserId,
                GETDATE(), GETDATE(), @ProductData, 'synced', GETDATE()
            );
        
        -- Update sync log as success
        UPDATE dbo.S
