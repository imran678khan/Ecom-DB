-- =============================================
-- Product Management Database Schema
-- Date: 2026-04-23
-- =============================================

USE [ProductManagementDB];
GO

-- =============================================
-- 1. BRANDS TABLE
-- =============================================
IF OBJECT_ID('dbo.Brands', 'U') IS NOT NULL
    DROP TABLE dbo.Brands;
GO

CREATE TABLE dbo.Brands (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL UNIQUE,
    Logo NVARCHAR(500) NULL,
    Description NVARCHAR(MAX) NULL,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);
GO

CREATE INDEX IX_Brands_Slug ON dbo.Brands(Slug);
CREATE INDEX IX_Brands_IsActive ON dbo.Brands(IsActive);
GO

-- =============================================
-- 2. CATEGORIES TABLE (Hierarchical)
-- =============================================
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL
    DROP TABLE dbo.Categories;
GO

CREATE TABLE dbo.Categories (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL UNIQUE,
    Description NVARCHAR(MAX) NULL,
    Image NVARCHAR(500) NULL,
    ParentCategoryId INT NULL,
    DisplayOrder INT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_Categories_ParentCategory FOREIGN KEY (ParentCategoryId) 
        REFERENCES dbo.Categories(Id) ON DELETE NO ACTION
);
GO

CREATE INDEX IX_Categories_Slug ON dbo.Categories(Slug);
CREATE INDEX IX_Categories_ParentCategoryId ON dbo.Categories(ParentCategoryId);
CREATE INDEX IX_Categories_IsActive ON dbo.Categories(IsActive);
GO

-- =============================================
-- 3. ATTRIBUTES TABLE
-- =============================================
IF OBJECT_ID('dbo.Attributes', 'U') IS NOT NULL
    DROP TABLE dbo.Attributes;
GO

CREATE TABLE dbo.Attributes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL UNIQUE,
    DisplayOrder INT DEFAULT 0,
    IsVariant BIT DEFAULT 1,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);
GO

CREATE INDEX IX_Attributes_Slug ON dbo.Attributes(Slug);
CREATE INDEX IX_Attributes_IsVariant ON dbo.Attributes(IsVariant);
CREATE INDEX IX_Attributes_IsActive ON dbo.Attributes(IsActive);
GO

-- =============================================
-- 4. ATTRIBUTE VALUES TABLE
-- =============================================
IF OBJECT_ID('dbo.AttributeValues', 'U') IS NOT NULL
    DROP TABLE dbo.AttributeValues;
GO

CREATE TABLE dbo.AttributeValues (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    AttributeId INT NOT NULL,
    Value NVARCHAR(200) NOT NULL,
    ValueSlug NVARCHAR(200) NOT NULL,
    DisplayOrder INT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_AttributeValues_Attributes FOREIGN KEY (AttributeId) 
        REFERENCES dbo.Attributes(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_AttributeValues_AttributeId_ValueSlug UNIQUE (AttributeId, ValueSlug)
);
GO

CREATE INDEX IX_AttributeValues_AttributeId ON dbo.AttributeValues(AttributeId);
CREATE INDEX IX_AttributeValues_IsActive ON dbo.AttributeValues(IsActive);
GO

-- =============================================
-- 5. PRODUCTS TABLE
-- =============================================
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL
    DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Slug NVARCHAR(200) NOT NULL UNIQUE,
    Description NVARCHAR(MAX) NULL,
    CategoryId INT NOT NULL,
    BrandId INT NULL,
    Sku NVARCHAR(100) NULL UNIQUE,
    Price DECIMAL(18,2) NOT NULL,
    ComparePrice DECIMAL(18,2) NULL,
    CostPrice DECIMAL(18,2) NULL,
    SeoTitle NVARCHAR(255) NULL,
    SeoDescription NVARCHAR(500) NULL,
    SeoKeywords NVARCHAR(500) NULL,
    IsActive BIT DEFAULT 1,
    IsFeatured BIT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_Products_Categories FOREIGN KEY (CategoryId) 
        REFERENCES dbo.Categories(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_Products_Brands FOREIGN KEY (BrandId) 
        REFERENCES dbo.Brands(Id) ON DELETE SET NULL,
    CONSTRAINT CK_Products_Price CHECK (Price > 0),
    CONSTRAINT CK_Products_ComparePrice CHECK (ComparePrice IS NULL OR ComparePrice > Price)
);
GO

CREATE INDEX IX_Products_Slug ON dbo.Products(Slug);
CREATE INDEX IX_Products_Sku ON dbo.Products(Sku);
CREATE INDEX IX_Products_CategoryId ON dbo.Products(CategoryId);
CREATE INDEX IX_Products_BrandId ON dbo.Products(BrandId);
CREATE INDEX IX_Products_IsActive ON dbo.Products(IsActive);
CREATE INDEX IX_Products_IsFeatured ON dbo.Products(IsFeatured);
GO

-- =============================================
-- 6. PRODUCT VARIANTS TABLE
-- =============================================
IF OBJECT_ID('dbo.ProductVariants', 'U') IS NOT NULL
    DROP TABLE dbo.ProductVariants;
GO

CREATE TABLE dbo.ProductVariants (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    Sku NVARCHAR(100) NOT NULL UNIQUE,
    VariantCombination NVARCHAR(MAX) NOT NULL, -- JSON format: [{"AttributeId": 1, "AttributeValueId": 5}]
    Price DECIMAL(18,2) NOT NULL,
    ComparePrice DECIMAL(18,2) NULL,
    CostPrice DECIMAL(18,2) NULL,
    StockQuantity INT DEFAULT 0,
    TrackInventory BIT DEFAULT 1,
    ImageUrl NVARCHAR(500) NULL,
    IsActive BIT DEFAULT 1,
    DisplayOrder INT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_ProductVariants_Products FOREIGN KEY (ProductId) 
        REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_ProductVariants_ProductId_VariantCombination UNIQUE (ProductId, VariantCombination),
    CONSTRAINT CK_ProductVariants_Price CHECK (Price > 0)
);
GO

CREATE INDEX IX_ProductVariants_Sku ON dbo.ProductVariants(Sku);
CREATE INDEX IX_ProductVariants_ProductId ON dbo.ProductVariants(ProductId);
CREATE INDEX IX_ProductVariants_IsActive ON dbo.ProductVariants(IsActive);
GO

-- =============================================
-- 7. VARIANT ATTRIBUTES TABLE
-- =============================================
IF OBJECT_ID('dbo.VariantAttributes', 'U') IS NOT NULL
    DROP TABLE dbo.VariantAttributes;
GO

CREATE TABLE dbo.VariantAttributes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    VariantId INT NOT NULL,
    AttributeId INT NOT NULL,
    AttributeValueId INT NOT NULL,
    CONSTRAINT FK_VariantAttributes_Variants FOREIGN KEY (VariantId) 
        REFERENCES dbo.ProductVariants(Id) ON DELETE CASCADE,
    CONSTRAINT FK_VariantAttributes_Attributes FOREIGN KEY (AttributeId) 
        REFERENCES dbo.Attributes(Id) ON DELETE NO ACTION,
    CONSTRAINT FK_VariantAttributes_AttributeValues FOREIGN KEY (AttributeValueId) 
        REFERENCES dbo.AttributeValues(Id) ON DELETE NO ACTION,
    CONSTRAINT UQ_VariantAttributes_VariantId_AttributeId UNIQUE (VariantId, AttributeId)
);
GO

CREATE INDEX IX_VariantAttributes_VariantId ON dbo.VariantAttributes(VariantId);
CREATE INDEX IX_VariantAttributes_AttributeId ON dbo.VariantAttributes(AttributeId);
CREATE INDEX IX_VariantAttributes_AttributeValueId ON dbo.VariantAttributes(AttributeValueId);
GO

-- =============================================
-- 8. PRODUCT IMAGES TABLE
-- =============================================
IF OBJECT_ID('dbo.ProductImages', 'U') IS NOT NULL
    DROP TABLE dbo.ProductImages;
GO

CREATE TABLE dbo.ProductImages (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    ProductId INT NOT NULL,
    VariantId INT NULL,
    ImageUrl NVARCHAR(500) NOT NULL,
    DisplayOrder INT DEFAULT 0,
    IsDefault BIT DEFAULT 0,
    AltText NVARCHAR(255) NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    CONSTRAINT FK_ProductImages_Products FOREIGN KEY (ProductId) 
        REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT FK_ProductImages_Variants FOREIGN KEY (VariantId) 
        REFERENCES dbo.ProductVariants(Id) ON DELETE SET NULL
);
GO

CREATE INDEX IX_ProductImages_ProductId ON dbo.ProductImages(ProductId);
CREATE INDEX IX_ProductImages_VariantId ON dbo.ProductImages(VariantId);
CREATE INDEX IX_ProductImages_IsDefault ON dbo.ProductImages(IsDefault);
GO

PRINT 'All tables created successfully!';
