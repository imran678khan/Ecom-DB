-- =============================================
-- TAX MANAGEMENT SYSTEM
-- Supports: Sales Tax, VAT, GST, Customs/Duties
-- Compatible with: Shopify, Magento, WooCommerce, Drupal
-- Date: 2026-04-23
-- =============================================

-- =============================================
-- 1. TAX ZONES / JURISDICTIONS
-- =============================================
IF OBJECT_ID('dbo.TaxZones', 'U') IS NOT NULL
    DROP TABLE dbo.TaxZones;
GO

CREATE TABLE dbo.TaxZones (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    ZoneCode NVARCHAR(50) NOT NULL,          -- 'EU-VAT', 'US-CA', 'IN-GST'
    ZoneName NVARCHAR(200) NOT NULL,
    ZoneType NVARCHAR(20) NOT NULL,          -- 'Country', 'State', 'City', 'PostalCode', 'Custom'
    TaxType NVARCHAR(20) NOT NULL,           -- 'VAT', 'GST', 'SalesTax', 'Customs'
    IsActive BIT DEFAULT 1,
    Priority INT DEFAULT 0,                   -- For overlapping zones
    
    -- Geolocation criteria
    Countries JSON NULL,                      -- ['US', 'CA', 'MX']
    States JSON NULL,                         -- ['CA', 'NY', 'TX']
    PostalCodes JSON NULL,                    -- ['90210', '10001-10030']
    Cities JSON NULL,                         -- ['Los Angeles', 'New York']
    
    -- External IDs for platform sync
    ExternalIds JSON NULL,
    
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxZones_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT UQ_TaxZones_Store_Code UNIQUE (StoreId, ZoneCode)
);
GO

-- =============================================
-- 2. TAX RATES
-- =============================================
IF OBJECT_ID('dbo.TaxRates', 'U') IS NOT NULL
    DROP TABLE dbo.TaxRates;
GO

CREATE TABLE dbo.TaxRates (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    TaxZoneId INT NOT NULL,
    RateCode NVARCHAR(100) NOT NULL,         -- 'CA-STATE', 'CA-LA-CITY'
    RateName NVARCHAR(200) NOT NULL,          -- 'California State Tax', 'Los Angeles City Tax'
    
    -- Rate details
    RatePercentage DECIMAL(8,4) NOT NULL,     -- 8.25% = 8.2500
    RateType NVARCHAR(20) NOT NULL,           -- 'Percentage', 'Fixed'
    FixedAmount DECIMAL(18,4) NULL,           -- For fixed-per-unit taxes
    
    -- Tax calculation priority
    CompoundWith NVARCHAR(50) NULL,           -- Which tax this compounds on (e.g., 'CA-STATE')
    IsCompound BIT DEFAULT 0,                 -- Applied on top of other taxes?
    IsShippingTaxable BIT DEFAULT 1,          -- Apply to shipping?
    SortOrder INT DEFAULT 0,
    
    -- Validity period
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE NULL,
    
    -- Tax category
    TaxCategory NVARCHAR(50) DEFAULT 'Standard', -- Standard, Reduced, Zero, Exempt
    
    -- External IDs
    ExternalIds JSON NULL,
    
    IsActive BIT DEFAULT 1,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxRates_TaxZone FOREIGN KEY (TaxZoneId) REFERENCES dbo.TaxZones(Id) ON DELETE CASCADE,
    CONSTRAINT FK_TaxRates_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT CK_TaxRates_RatePercentage CHECK (RatePercentage >= 0 AND RatePercentage <= 100),
    CONSTRAINT CK_TaxRates_FixedAmount CHECK (FixedAmount IS NULL OR FixedAmount >= 0)
);
GO

-- =============================================
-- 3. TAX CATEGORIES / TAX CLASSES
-- =============================================
IF OBJECT_ID('dbo.TaxClasses', 'U') IS NOT NULL
    DROP TABLE dbo.TaxClasses;
GO

CREATE TABLE dbo.TaxClasses (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    ClassCode NVARCHAR(50) NOT NULL,          -- 'STANDARD', 'REDUCED', 'FOOD', 'BOOKS', 'CLOTHING'
    ClassName NVARCHAR(200) NOT NULL,
    Description NVARCHAR(500) NULL,
    DefaultRate DECIMAL(8,4) NULL,            -- Default rate if no specific rate found
    IsActive BIT DEFAULT 1,
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxClasses_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT UQ_TaxClasses_Store_Code UNIQUE (StoreId, ClassCode)
);
GO

-- =============================================
-- 4. PRODUCT TAX CLASS MAPPING
-- =============================================
-- Add to Products table (modify existing)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Products') AND name = 'TaxClassId')
BEGIN
    ALTER TABLE dbo.Products ADD TaxClassId INT NULL;
    ALTER TABLE dbo.Products ADD CONSTRAINT FK_Products_TaxClass FOREIGN KEY (TaxClassId) 
        REFERENCES dbo.TaxClasses(Id);
END
GO

-- Also add to Variants (for override)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Variants') AND name = 'TaxClassId')
BEGIN
    ALTER TABLE dbo.Variants ADD TaxClassId INT NULL;
    ALTER TABLE dbo.Variants ADD CONSTRAINT FK_Variants_TaxClass FOREIGN KEY (TaxClassId) 
        REFERENCES dbo.TaxClasses(Id);
END
GO

-- =============================================
-- 5. TAX RATE X PRODUCT CATEGORY MAPPING (Special rates for categories)
-- =============================================
IF OBJECT_ID('dbo.TaxRateCategoryMappings', 'U') IS NOT NULL
    DROP TABLE dbo.TaxRateCategoryMappings;
GO

CREATE TABLE dbo.TaxRateCategoryMappings (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    TaxRateId INT NOT NULL,
    TaxonomyTermId INT NOT NULL,              -- Product category
    Priority INT DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TRCM_TaxRate FOREIGN KEY (TaxRateId) REFERENCES dbo.TaxRates(Id) ON DELETE CASCADE,
    CONSTRAINT FK_TRCM_Term FOREIGN KEY (TaxonomyTermId) REFERENCES dbo.TaxonomyTerms(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_TaxRateCategoryMappings UNIQUE (TaxRateId, TaxonomyTermId)
);
GO

-- =============================================
-- 6. CUSTOMER TAX EXEMPTIONS
-- =============================================
IF OBJECT_ID('dbo.TaxExemptCertificates', 'U') IS NOT NULL
    DROP TABLE dbo.TaxExemptCertificates;
GO

CREATE TABLE dbo.TaxExemptCertificates (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    CustomerId INT NOT NULL,                  -- References your Customer table
    TaxZoneId INT NOT NULL,
    ExemptionNumber NVARCHAR(100) NOT NULL,
    ExemptionType NVARCHAR(50) NOT NULL,      -- 'Resale', 'NonProfit', 'Government', 'Agricultural'
    IssuedDate DATE NOT NULL,
    ExpiryDate DATE NULL,
    VerifiedAt DATETIME2 NULL,
    VerifiedBy NVARCHAR(100) NULL,
    CertificateUrl NVARCHAR(500) NULL,
    IsActive BIT DEFAULT 1,
    Notes NVARCHAR(MAX) NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxExemptCertificates_TaxZone FOREIGN KEY (TaxZoneId) REFERENCES dbo.TaxZones(Id),
    CONSTRAINT UQ_TaxExemptCertificates_Customer_Zone UNIQUE (CustomerId, TaxZoneId)
);
GO

-- =============================================
-- 7. TAX TRANSACTIONS (Audit trail)
-- =============================================
IF OBJECT_ID('dbo.TaxTransactions', 'U') IS NOT NULL
    DROP TABLE dbo.TaxTransactions;
GO

CREATE TABLE dbo.TaxTransactions (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    TransactionType NVARCHAR(20) NOT NULL,    -- 'Order', 'Invoice', 'CreditNote', 'PO'
    TransactionId INT NOT NULL,               -- Order ID or Invoice ID
    TransactionNumber NVARCHAR(100) NULL,
    TaxRateId INT NOT NULL,
    TaxClassId INT NULL,
    TaxZoneId INT NOT NULL,
    JurisdictionName NVARCHAR(200) NULL,      -- Snapshot of tax jurisdiction
    
    -- Taxable amounts
    TaxableAmount DECIMAL(18,4) NOT NULL,
    TaxAmount DECIMAL(18,4) NOT NULL,
    TaxRatePercentage DECIMAL(8,4) NOT NULL,
    
    -- Tracking
    IsCompounded BIT DEFAULT 0,
    IsReconciled BIT DEFAULT 0,
    ReconciledAt DATETIME2 NULL,
    
    ExternalReference NVARCHAR(255) NULL,     -- Reference to external tax calculation
    
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxTransactions_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT FK_TaxTransactions_TaxRate FOREIGN KEY (TaxRateId) REFERENCES dbo.TaxRates(Id),
    CONSTRAINT FK_TaxTransactions_TaxZone FOREIGN KEY (TaxZoneId) REFERENCES dbo.TaxZones(Id),
    CONSTRAINT FK_TaxTransactions_TaxClass FOREIGN KEY (TaxClassId) REFERENCES dbo.TaxClasses(Id)
);
GO

-- =============================================
-- 8. ORDER TAX BREAKDOWN (For sales orders)
-- =============================================
IF OBJECT_ID('dbo.OrderTaxBreakdown', 'U') IS NOT NULL
    DROP TABLE dbo.OrderTaxBreakdown;
GO

CREATE TABLE dbo.OrderTaxBreakdown (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    OrderId INT NOT NULL,                     -- References your Orders table
    TaxTransactionId INT NOT NULL,
    TaxZoneId INT NOT NULL,
    
    -- Applied to what?
    AppliedToEntityType NVARCHAR(20) NOT NULL, -- 'Product', 'Shipping', 'GiftWrap', 'Service'
    AppliedToEntityId INT NULL,                -- Product ID, Variant ID, etc.
    AppliedToName NVARCHAR(500) NULL,          -- Snapshot
    
    -- Breakdown
    TaxableAmount DECIMAL(18,4) NOT NULL,
    TaxAmount DECIMAL(18,4) NOT NULL,
    TaxRatePercentage DECIMAL(8,4) NOT NULL,
    
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_OrderTaxBreakdown_TaxTransaction FOREIGN KEY (TaxTransactionId) 
        REFERENCES dbo.TaxTransactions(Id),
    CONSTRAINT FK_OrderTaxBreakdown_TaxZone FOREIGN KEY (TaxZoneId) 
        REFERENCES dbo.TaxZones(Id)
);
GO

-- =============================================
-- 9. CROSS-BORDER / CUSTOMS DUTIES TARIFFS
-- =============================================
IF OBJECT_ID('dbo.TariffCodes', 'U') IS NOT NULL
    DROP TABLE dbo.TariffCodes;
GO

CREATE TABLE dbo.TariffCodes (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    Code NVARCHAR(20) NOT NULL UNIQUE,        -- HS Code: 6109.10.0012
    Description NVARCHAR(500) NOT NULL,
    DutyRate DECIMAL(8,4) NULL,               -- Import duty rate
    VatRate DECIMAL(8,4) NULL,                -- VAT on imports
    ExciseRate DECIMAL(8,4) NULL,             -- Excise duty
    IsActive BIT DEFAULT 1,
    CountryOfOriginEffect NVARCHAR(3) NULL,   -- Special rates for specific origin
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- Add TariffCode to Variants
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Variants') AND name = 'TariffCodeId')
BEGIN
    ALTER TABLE dbo.Variants ADD TariffCodeId INT NULL;
    ALTER TABLE dbo.Variants ADD CONSTRAINT FK_Variants_TariffCode FOREIGN KEY (TariffCodeId) 
        REFERENCES dbo.TariffCodes(Id);
END
GO

-- =============================================
-- 10. TAX CALCULATION LOGS (For debugging/audit)
-- =============================================
IF OBJECT_ID('dbo.TaxCalculationLogs', 'U') IS NOT NULL
    DROP TABLE dbo.TaxCalculationLogs;
GO

CREATE TABLE dbo.TaxCalculationLogs (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    RequestId UNIQUEIDENTIFIER NOT NULL,
    TransactionType NVARCHAR(20) NOT NULL,
    TransactionId INT NULL,
    RequestData JSON NOT NULL,                -- What was sent to tax engine
    ResponseData JSON NULL,                   -- What came back
    CalculatedTaxAmount DECIMAL(18,4) NULL,
    CalculationTimeMs INT NULL,
    IsSuccessful BIT NOT NULL DEFAULT 1,
    ErrorMessage NVARCHAR(MAX) NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxCalcLogs_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id)
);
GO

-- =============================================
-- 11. TAX REGISTRATION (Seller's tax registrations)
-- =============================================
IF OBJECT_ID('dbo.TaxRegistrations', 'U') IS NOT NULL
    DROP TABLE dbo.TaxRegistrations;
GO

CREATE TABLE dbo.TaxRegistrations (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    TaxZoneId INT NOT NULL,
    RegistrationNumber NVARCHAR(100) NOT NULL, -- VAT ID, GSTIN, Sales Tax ID
    RegistrationName NVARCHAR(200) NULL,
    RegistrationDate DATE NOT NULL,
    ValidationDate DATE NULL,
    IsValid BIT DEFAULT 1,
    ExpiryDate DATE NULL,
    ExternalIds JSON NULL,
    CreatedAt DATETIME2 DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_TaxRegistrations_Store FOREIGN KEY (StoreId) REFERENCES dbo.Stores(Id),
    CONSTRAINT FK_TaxRegistrations_TaxZone FOREIGN KEY (TaxZoneId) REFERENCES dbo.TaxZones(Id),
    CONSTRAINT UQ_TaxRegistrations_Store_Zone UNIQUE (StoreId, TaxZoneId)
);
GO

-- =============================================
-- 12. MODIFY PURCHASE ORDER ITEMS FOR TAX
-- =============================================
-- Add tax columns to PurchaseOrderItems if not exists
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.PurchaseOrderItems') AND name = 'TaxRateId')
BEGIN
    ALTER TABLE dbo.PurchaseOrderItems ADD TaxRateId INT NULL;
    ALTER TABLE dbo.PurchaseOrderItems ADD ImportDutyRate DECIMAL(8,4) NULL;
    ALTER TABLE dbo.PurchaseOrderItems ADD LandedCostAdjustment DECIMAL(18,4) NULL;
    
    ALTER TABLE dbo.PurchaseOrderItems ADD CONSTRAINT FK_POItems_TaxRate FOREIGN KEY (TaxRateId) 
        REFERENCES dbo.TaxRates(Id);
END
GO

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

CREATE INDEX IX_TaxRates_TaxZoneId ON dbo.TaxRates(TaxZoneId);
CREATE INDEX IX_TaxRates_EffectiveDate ON dbo.TaxRates(EffectiveFrom, EffectiveTo) WHERE IsActive = 1;
CREATE INDEX IX_TaxZones_GeoSearch ON dbo.TaxZones(ZoneType);
CREATE INDEX IX_TaxTransactions_Transaction ON dbo.TaxTransactions(TransactionType, TransactionId);
CREATE INDEX IX_TaxTransactions_CreatedAt ON dbo.TaxTransactions(CreatedAt);
CREATE INDEX IX_OrderTaxBreakdown_OrderId ON dbo.OrderTaxBreakdown(OrderId);
CREATE INDEX IX_TaxExemptCertificates_Customer ON dbo.TaxExemptCertificates(CustomerId, IsActive);
CREATE INDEX IX_TaxCalculationLogs_RequestId ON dbo.TaxCalculationLogs(RequestId);
CREATE INDEX IX_TaxCalculationLogs_CreatedAt ON dbo.TaxCalculationLogs(CreatedAt);
CREATE INDEX IX_TaxRegistrations_StoreZone ON dbo.TaxRegistrations(StoreId, TaxZoneId);
CREATE INDEX IX_TariffCodes_Code ON dbo.TariffCodes(Code);

-- JSON indexes for geolocation queries
CREATE INDEX IX_TaxZones_Countries ON dbo.TaxZones(JSON_VALUE(Countries, '$[0]'));
GO

-- =============================================
-- HELPER FUNCTIONS & STORED PROCEDURES
-- =============================================

-- Function: Get applicable tax rate for a product in a location
IF OBJECT_ID('dbo.fn_GetTaxRate', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetTaxRate;
GO

CREATE FUNCTION dbo.fn_GetTaxRate(
    @StoreId INT,
    @ProductId INT,
    @VariantId INT,
    @CountryCode NVARCHAR(2),
    @StateCode NVARCHAR(10) = NULL,
    @PostalCode NVARCHAR(20) = NULL,
    @TaxCategory NVARCHAR(50) = 'Standard'
)
RETURNS TABLE
AS
RETURN
(
    SELECT 
        tr.Id AS TaxRateId,
        tr.RateCode,
        tr.RatePercentage,
        tr.TaxCategory,
        tr.IsCompound,
        tr.CompoundWith,
        tz.ZoneCode,
        tz.ZoneName,
        ROW_NUMBER() OVER (ORDER BY tz.Priority DESC, tr.SortOrder) AS CalculationOrder
    FROM TaxRates tr
    JOIN TaxZones tz ON tr.TaxZoneId = tz.Id
    LEFT JOIN Products p ON p.Id = @ProductId
    LEFT JOIN Variants v ON v.Id = @VariantId
    WHERE tr.StoreId = @StoreId
        AND tr.IsActive = 1
        AND GETUTCDATE() BETWEEN tr.EffectiveFrom AND ISNULL(tr.EffectiveTo, '9999-12-31')
        AND tz.IsActive = 1
        AND (
            -- Match product tax class
            (v.TaxClassId IS NOT NULL AND v.TaxClassId = tr.TaxClassId)
            OR (p.TaxClassId IS NOT NULL AND p.TaxClassId = tr.TaxClassId)
            OR (tr.TaxClassId IS NULL) -- Default rate
        )
        -- Match location criteria
        AND EXISTS (
            SELECT 1 
            FROM OPENJSON(tz.Countries) 
            WHERE VALUE = @CountryCode
        )
        AND (
            @StateCode IS NULL 
            OR NOT EXISTS (SELECT 1 FROM OPENJSON(tz.States))
            OR EXISTS (SELECT 1 FROM OPENJSON(tz.States) WHERE VALUE = @StateCode)
        )
        AND (
            @PostalCode IS NULL 
            OR NOT EXISTS (SELECT 1 FROM OPENJSON(tz.PostalCodes))
            OR EXISTS (SELECT 1 FROM OPENJSON(tz.PostalCodes) WHERE @PostalCode LIKE VALUE)
        )
);
GO

-- Stored Procedure: Calculate taxes for an order
IF OBJECT_ID('dbo.usp_CalculateOrderTax', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CalculateOrderTax;
GO

CREATE PROCEDURE dbo.usp_CalculateOrderTax
    @OrderId INT,
    @StoreId INT,
    @ShippingAddressCountry NVARCHAR(2),
    @ShippingAddressState NVARCHAR(10) = NULL,
    @ShippingAddressPostalCode NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TaxCalculationId UNIQUEIDENTIFIER = NEWID();
    DECLARE @StartTime DATETIME2 = GETUTCDATE();
    DECLARE @Success BIT = 1;
    DECLARE @ErrorMessage NVARCHAR(MAX) = NULL;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Clear existing tax calculations for this order
        DELETE FROM OrderTaxBreakdown WHERE OrderId = @OrderId;
        DELETE FROM TaxTransactions WHERE TransactionType = 'Order' AND TransactionId = @OrderId;
        
        -- Calculate tax for each order line item
        -- (Assuming you have an OrderItems table)
        INSERT INTO TaxTransactions (
            StoreId, TransactionType, TransactionId, TransactionNumber,
            TaxRateId, TaxClassId, TaxZoneId, JurisdictionName,
            TaxableAmount, TaxAmount, TaxRatePercentage, IsCompounded,
            CreatedAt
        )
        SELECT 
            @StoreId,
            'Order',
            @OrderId,
            NULL,
            t.TaxRateId,
            COALESCE(v.TaxClassId, p.TaxClassId) AS TaxClassId,
            tz.Id,
            tz.ZoneName,
            oi.UnitPrice * oi.Quantity AS TaxableAmount,
            (oi.UnitPrice * oi.Quantity) * (t.RatePercentage / 100) AS TaxAmount,
            t.RatePercentage,
            t.IsCompound,
            GETUTCDATE()
        FROM OrderItems oi
        JOIN Variants v ON oi.VariantId = v.Id
        JOIN Products p ON v.ProductId = p.Id
        CROSS APPLY dbo.fn_GetTaxRate(
            @StoreId, 
            p.Id, 
            v.Id, 
            @ShippingAddressCountry, 
            @ShippingAddressState, 
            @ShippingAddressPostalCode,
            'Standard'
        ) t
        JOIN TaxZones tz ON t.TaxZoneId = tz.Id
        WHERE oi.OrderId = @OrderId;
        
        -- Log successful calculation
        INSERT INTO TaxCalculationLogs (
            StoreId, RequestId, TransactionType, TransactionId,
            RequestData, CalculatedTaxAmount, CalculationTimeMs, IsSuccessful,
            CreatedAt
        )
        VALUES (
            @StoreId, @TaxCalculationId, 'Order', @OrderId,
            (SELECT 
                @OrderId AS OrderId,
                @ShippingAddressCountry AS Country,
                @ShippingAddressState AS State,
                @ShippingAddressPostalCode AS PostalCode
            FOR JSON AUTO),
            (SELECT SUM(TaxAmount) FROM TaxTransactions WHERE TransactionType = 'Order' AND TransactionId = @OrderId),
            DATEDIFF(MILLISECOND, @StartTime, GETUTCDATE()),
            1,
            GETUTCDATE()
        );
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Success = 0;
        SET @ErrorMessage = ERROR_MESSAGE();
        
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        
        -- Log error
        INSERT INTO TaxCalculationLogs (
            StoreId, RequestId, TransactionType, TransactionId,
            RequestData, ErrorMessage, IsSuccessful, CreatedAt
        )
        VALUES (
            @StoreId, @TaxCalculationId, 'Order', @OrderId,
            (SELECT @OrderId AS OrderId FOR JSON AUTO),
            @ErrorMessage,
            0,
            GETUTCDATE()
        );
        
        THROW;
    END CATCH
END;
GO

-- Stored Procedure: Calculate landed cost including taxes for PO receipt
IF OBJECT_ID('dbo.usp_CalculateLandedCost', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_CalculateLandedCost;
GO

CREATE PROCEDURE dbo.usp_CalculateLandedCost
    @PurchaseOrderItemId INT,
    @ReceivedQuantity INT
AS
BEGIN
    DECLARE @LandedCost DECIMAL(18,4);
    DECLARE @UnitCost DECIMAL(18,4);
    DECLARE @DutyRate DECIMAL(8,4);
    DECLARE @TaxRate DECIMAL(8,4);
    DECLARE @ShippingAllocation DECIMAL(18,4);
    
    -- Get base cost
    SELECT @UnitCost = UnitCost
    FROM PurchaseOrderItems
    WHERE Id = @PurchaseOrderItemId;
    
    -- Get duty rate from product's tariff code
    SELECT @DutyRate = ISNULL(tc.DutyRate, 0)
    FROM PurchaseOrderItems poi
    JOIN Variants v ON poi.VariantId = v.Id
    LEFT JOIN TariffCodes tc ON v.TariffCodeId = tc.Id
    WHERE poi.Id = @PurchaseOrderItemId;
    
    -- Calculate landed cost per unit
    SET @LandedCost = @UnitCost 
        + (@UnitCost * @DutyRate / 100)  -- Add duty
        + (@UnitCost * @TaxRate / 100);   -- Add tax
    
    -- Update PO item with landed cost
    UPDATE PurchaseOrderItems
    SET LandedCostAdjustment = @LandedCost - @UnitCost,
        UpdatedAt = GETUTCDATE()
    WHERE Id = @PurchaseOrderItemId;
    
    -- Return calculated landed cost
    SELECT @LandedCost AS LandedCostPerUnit;
END;
GO

-- =============================================
-- VIEWS FOR REPORTING
-- =============================================

-- View: Tax liability by period
IF OBJECT_ID('dbo.vwTaxLiability', 'V') IS NOT NULL
    DROP VIEW dbo.vwTaxLiability;
GO

CREATE VIEW dbo.vwTaxLiability AS
SELECT 
    tt.StoreId,
    YEAR(tt.CreatedAt) AS TaxYear,
    MONTH(tt.CreatedAt) AS TaxMonth,
    tz.ZoneCode,
    tz.ZoneName,
    tr.RateCode,
    tr.RatePercentage,
    COUNT(DISTINCT tt.TransactionId) AS TransactionCount,
    SUM(tt.TaxableAmount) AS TotalTaxableAmount,
    SUM(tt.TaxAmount) AS TotalTaxAmount,
    SUM(CASE WHEN tt.IsReconciled = 1 THEN tt.TaxAmount ELSE 0 END) AS ReconciledTaxAmount,
    SUM(CASE WHEN tt.IsReconciled = 0 THEN tt.TaxAmount ELSE 0 END) AS UnreconciledTaxAmount
FROM TaxTransactions tt
JOIN TaxZones tz ON tt.TaxZoneId = tz.Id
JOIN TaxRates tr ON tt.TaxRateId = tr.Id
WHERE tt.TransactionType IN ('Order', 'Invoice')
GROUP BY tt.StoreId, YEAR(tt.CreatedAt), MONTH(tt.CreatedAt), 
         tz.ZoneCode, tz.ZoneName, tr.RateCode, tr.RatePercentage;
GO

-- View: Product taxability summary
IF OBJECT_ID('dbo.vwProductTaxability', 'V') IS NOT NULL
    DROP VIEW dbo.vwProductTaxability;
GO

CREATE VIEW dbo.vwProductTaxability AS
SELECT 
    p.Id AS ProductId,
    p.Name AS ProductName,
    p.Sku AS ProductSku,
    tc.ClassCode AS TaxClassCode,
    tc.ClassName AS TaxClassName,
    v.Sku AS VariantSku,
    v.TaxClassId AS VariantTaxOverride
FROM Products p
LEFT JOIN TaxClasses tc ON p.TaxClassId = tc.Id
LEFT JOIN Variants v ON p.Id = v.ProductId;
GO

PRINT 'Tax Management schema created successfully!';
PRINT 'Includes: Sales Tax, VAT, GST, Customs Duties';
GO
