codeunit 50099 BaseModificationCodeunitt
{
    Permissions = TableData "Approval Entry" = imd,
    tabledata "Sales Shipment Header" = m,
    tabledata "Sales Invoice Header" = m,
    tabledata "Sales Cr.Memo Header" = m,
    tabledata "Inventory Adjmt. Entry (Order)" = m,
    tabledata "Reservation Entry" = m,
    tabledata "Active Session" = RIMD,
    tabledata "Purch. Cr. Memo Line" = m,
    tabledata "Purch. Rcpt. Line" = im,
    tabledata "G/L Account" = rm,
    tabledata "Job Queue Entry" = rmd,
    tabledata "Sales Shipment Line" = im,
    tabledata "Transfer Shipment Line" = im;

    [EventSubscriber(ObjectType::Table, Database::"Ship-to Address", 'OnAfterValidateEvent', 'GST Registration No.', false, false)]
    local procedure validateShiptoAddGSTRegistrationNo(var Rec: Record "Ship-to Address")
    begin
        if Rec."GST Registration No." <> '' then
            Rec."Ship-to GST Customer Type" := rec."Ship-to GST Customer Type"::Registered
        Else
            Rec."Ship-to GST Customer Type" := rec."Ship-to GST Customer Type"::Unregistered;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Ship-to Address", OnAfterInsertEvent, '', false, false)]
    local procedure OnAfterInsertEventShiptoCode(var Rec: Record "Ship-to Address")
    begin
        Rec."Ship-to GST Customer Type" := rec."Ship-to GST Customer Type"::Unregistered;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Calculate Prod. Order", 'OnTransferBOMOnAfterSetFiltersProdBOMLine', '', true, true)]
    local procedure "Calculate Prod. Order_OnTransferBOMOnAfterSetFiltersProdBOMLine"
        (
            var ProdBOMLine: Record "Production BOM Line";
            ProdOrderLine: Record "Prod. Order Line"
        )
    var
        ProOrder: Record "Production Order";
    begin
        ProOrder.Get(ProOrder.Status::Released, ProdOrderLine."Prod. Order No.");
        ProdBOMLine.SetRange("Version Code", ProOrder."BOM Version No");
    end;


    //S.M


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Prod. Order Status Management", 'OnAfterChangeStatusOnProdOrder', '', true, true)]
    local procedure "Prod. Order Status Management_OnAfterChangeStatusOnProdOrder"
    (
        var ProdOrder: Record "Production Order";
        var ToProdOrder: Record "Production Order";
        NewStatus: Enum "Production Order Status";
        NewPostingDate: Date;
        NewUpdateUnitCost: Boolean;
        var SuppressCommit: Boolean
    )
    var
        ItemRec: Record Item;
        RemQty: Decimal;
        ILE: Record "Item Ledger Entry";
        ProductionBOMLine: Record "Production BOM Line";
        ProductionBOMHeader: Record "Production BOM Header";
        ProdOrderComponent: Record "Prod. Order Component";
    begin
        //PruRaj_RQ_0.01

        ProdOrderComponent.RESET;
        ProdOrderComponent.SETRANGE("Prod. Order No.", ProdOrder."No.");
        ProdOrderComponent.SetRange("Flushing Method", ProdOrderComponent."Flushing Method"::Backward);
        IF ProdOrderComponent.FINDSET THEN
            REPEAT
                CLEAR(RemQty);
                ILE.RESET;
                ILE.SETRANGE("Item No.", ProdOrderComponent."Item No.");
                ILE.SETRANGE("Posting Date", 0D, NewPostingDate);
                ILE.SETRANGE("Location Code", ProdOrderComponent."Location Code");
                IF ILE.FINDSET THEN BEGIN
                    ILE.CALCSUMS("Remaining Quantity");
                    RemQty := ILE."Remaining Quantity";
                END;
                //MESSAGE('Rem Qty %1 ',RemQty);
                IF RemQty < ProdOrderComponent."Remaining Quantity" THEN
                    ERROR('Stock not available of Item No %1 of %2 Location', ProdOrderComponent."Item No.", ProdOrderComponent."Location Code");

            until ProdOrderComponent.Next() = 0;
    end;
    //S.M 25/05/2023
    [EventSubscriber(ObjectType::Report, Report::"Refresh Production Order", 'OnBeforeCalcProdOrder', '', true, true)]
    local procedure "Refresh Production Order_OnBeforeCalcProdOrder"
    (
        var ProductionOrder: Record "Production Order";
        Direction: Option
    )
    var
        ItemRec: Record Item;

    begin
        if ProductionOrder."Source Type" = ProductionOrder."Source Type"::Item then
            if ItemRec.Get(ProductionOrder."Source No.") then begin
                if ItemRec."Production BOM No." = '' then begin
                    ItemRec."Production BOM No." := ProductionOrder."Prod. Bom No.";
                    ItemRec.Modify();
                    ProductionOrder.Check := true;
                END;
            end;
    end;


    [EventSubscriber(ObjectType::Report, Report::"Refresh Production Order", 'OnAfterRefreshProdOrder', '', true, true)]
    local procedure "Refresh Production Order_OnAfterRefreshProdOrder"
    (
        var ProductionOrder: Record "Production Order";
        ErrorOccured: Boolean
    )
    var
        ItemRec: Record Item;
    begin
        if ProductionOrder."Source Type" = ProductionOrder."Source Type"::Item then
            if ItemRec.Get(ProductionOrder."Source No.") then begin
                if ProductionOrder.Check = true then begin
                    ItemRec."Production BOM No." := '';
                    ItemRec.Modify();
                END;
            end;
    end;




    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Purch.-Post", OnBeforePostInvPostBuffer, '', false, false)]
    local procedure OnBeforePostInvPostBuffer(var GenJnlLine: Record "Gen. Journal Line"; var InvoicePostBuffer: Record "Invoice Post. Buffer"; var PurchHeader: Record "Purchase Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; PreviewMode: Boolean; CommitIsSupressed: Boolean; var GenJnlLineDocNo: code[20])
    begin
        GenJnlLine."User ID" := PurchHeader."SFPL User ID";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", OnAfterCopyItemJnlLineFromPurchHeader, '', false, false)]
    procedure OnAfterCopyItemJnlLineFromPurchHeader(var ItemJnlLine: Record "Item Journal Line"; PurchHeader: Record "Purchase Header")
    begin
        ItemJnlLine.SFPLUserID := PurchHeader."SFPL User ID";
    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Item Jnl.-Post Line", OnAfterInsertValueEntry, '', false, false)]
    procedure OnAfterInsertValueEntry(var ValueEntry: Record "Value Entry"; ItemJournalLine: Record "Item Journal Line"; var ItemLedgerEntry: Record "Item Ledger Entry"; var ValueEntryNo: Integer)
    begin
        ValueEntry."SFPL User ID" := ItemJournalLine.SFPLUserID;
    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Inventory Posting To G/L", OnPostInvtPostBufOnAfterInitGenJnlLine, '', false, false)]
    procedure OnPostInvtPostBufOnAfterInitGenJnlLine(var GenJournalLine: Record "Gen. Journal Line"; var ValueEntry: Record "Value Entry")
    begin
        GenJournalLine."User ID" := ValueEntry."SFPL User ID";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", OnBeforeCreateDim, '', false, false)]
    local procedure OnBeforeCreateDim(var PurchaseHeader: Record "Purchase Header"; var IsHandled: Boolean; var DefaultDimSource: List of [Dictionary of [Integer, Code[20]]]; CurrentFieldNo: Integer)
    begin
        //if UserId = 'JOBQUEUE' then
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Released Prod. Order Lines", OnBeforeValidateEvent, 'Item No.', false, false)]
    Local procedure test(Rec: Record "Prod. Order Line")
    var
        ReleProdLine: Record "Prod. Order Line";
    begin

        ReleProdLine.Reset();
        ReleProdLine.SetRange("Prod. Order No.", rec."Prod. Order No.");
        ReleProdLine.SetRange(Status, Enum::"Production Order Status"::Released);
        ReleProdLine.SetRange("Item No.", Rec."Item No.");
        if ReleProdLine.FindFirst() then
            Error('The Item No. %1 already exist in Prod Order Line No. %2 and Order No. %3', ReleProdLine."Item No.", ReleProdLine."Line No.", ReleProdLine."Prod. Order No.");
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Production Order", OnAfterValidateEvent, 'Due date', false, false)]
    local procedure OnAfterValidateEventDuedate(var Rec: Record "Production Order")
    var
        Companyinfo: Record "Company Information";
    begin
        Companyinfo.Get;
        If Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] then
            GenerateBatchNoONProdOrder(Rec);
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Production Order", OnAfterValidateEvent, 'RPO Type', false, false)]
    local procedure OnAfterValidateEventRPOType(var Rec: Record "Production Order")
    var
        Companyinfo: Record "Company Information";
    begin
        Companyinfo.Get;
        If Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] then
            GenerateBatchNoONProdOrder(Rec);
    end;

    procedure GenerateBatchNoONProdOrder(var Rec: Record "Production Order")
    var
        Companyinfo: Record "Company Information";
        ProdOrder: Record "Production Order";
        PeriodYear: Integer;
        StartDate: Date;
        EndDate: Date;
        NoofDaysInYear: Integer;
        BatchMaster: Record "Batch Master";
        LotNo: text;
        LotType: Option ,"LB","RP","TP";

    begin
        Companyinfo.Get;
        If Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] then begin
            if (Rec."RPO Type" <> Rec."RPO Type"::" ") AND (Rec."Due Date" <> 0D) then begin
                PeriodYear := DATE2DMY(Rec."Due Date", 3);
                StartDate := DMY2DATE(1, 1, PeriodYear);
                EndDate := DMY2DATE(31, 12, PeriodYear);
                NoofDaysInYear := EndDate - StartDate;

                case Rec."RPO Type" of
                    Rec."RPO Type"::Processing:
                        LotType := LotType::LB;
                    Rec."RPO Type"::Portion:
                        LotType := LotType::LB;
                    Rec."RPO Type"::"Re-Process":
                        LotType := LotType::RP;
                    Rec."RPO Type"::"Third Party":
                        LotType := LotType::TP;
                end;

                LotNo := FORMAT(PeriodYear) + '/' + FORMAT(LotType) + '-' + FORMAT((EndDate - Rec."Due Date") + 1);

                BatchMaster.Reset();
                BatchMaster.SetRange("Batch No.", LotNo);
                if not BatchMaster.FindFirst() then begin
                    BatchMaster.Init();
                    BatchMaster."Batch Date" := Rec."Due Date";
                    BatchMaster."Batch No." := LotNo;
                    BatchMaster."Batch Type" := LotType;
                    BatchMaster.Insert();
                end;
                Rec."Lot No." := LotNo;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Production Journal Mgt", 'OnAfterInsertOutputJnlLine', '', false, false)]
    local procedure OnOnAfterInsertOutputJnlLine(var ItemJournalLine: Record "Item Journal Line")
    var
        Companyinfo: Record "Company Information";
    begin
        Companyinfo.Get;
        If Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] then
            If ItemJournalLine."Output Quantity" = 0 then
                ItemJournalLine.Delete();

    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Reference Invoice No. Mgt.", 'OnBeforeCheckRefInvNoPurchHeader', '', false, false)]
    local procedure OnBeforeCheckRefInvNoPurchaseHeader(var PurchaseHeader: Record "Purchase Header"; IsHandled: Boolean)
    begin
        IsHandled := True;
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Sales Header", 'OnBeforeUpdateLocationCode', '', false, false)]
    local procedure OnBeforeUpdateLocationCodeSales(var SalesHeader: Record "Sales Header"; LocationCode: Code[10]; var IsHandled: Boolean)
    begin
        IsHandled := True;
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Purchase Header", 'OnBeforeUpdateLocationCode', '', false, false)]
    local procedure OnBeforeUpdateLocationCode(var PurchaseHeader: Record "Purchase Header"; LocationCode: Code[10]; var IsHandled: Boolean)
    begin
        IsHandled := True;
    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Item Jnl.-Post Batch", 'OnBeforeCheckItemAvailability', '', false, false)]
    local procedure OnBeforeCheckItemAvailability(var ItemJournalLine: Record "Item Journal Line"; var StockkeepingUnit: Record "Stockkeeping Unit")
    var
        QtyinItemJnlLine: Decimal;
        AvailableQty: Decimal;
        ConfirmManagement: Codeunit "Confirm Management";
        Text010: Label 'One or more reservation entries exist for the item with %1 = %2, %3 = %4, %5 = %6 which may be disrupted if you post this negative adjustment. Do you want to continue?', Comment = 'One or more reservation entries exist for the item with Item No. = 1000, Location Code = BLUE, Variant Code = NEW which may be disrupted if you post this negative adjustment. Do you want to continue?';
    begin
        if StockkeepingUnit.FindSet() then
            repeat
                QtyinItemJnlLine := CalcRequiredQty(StockkeepingUnit, ItemJournalLine);
                if QtyinItemJnlLine < 0 then begin
                    Item.Get(StockkeepingUnit."Item No.");
                    Item.SetFilter("Location Filter", StockkeepingUnit."Location Code");
                    Item.SetFilter("Variant Filter", StockkeepingUnit."Variant Code");
                    Item.SetRange("Date Filter", ItemJournalLine."Posting Date");
                    Item.CalcFields("Reserved Qty. on Inventory", "Net Change");
                    AvailableQty := Item."Net Change" - Item."Reserved Qty. on Inventory" + SelfReservedQty(StockkeepingUnit, ItemJournalLine);

                    if (Item."Reserved Qty. on Inventory" > 0) and (AvailableQty < Abs(QtyinItemJnlLine)) then
                        if not ConfirmManagement.GetResponseOrDefault(
                            StrSubstNo(
                                Text010, StockkeepingUnit.FieldCaption("Item No."), StockkeepingUnit."Item No.", StockkeepingUnit.FieldCaption("Location Code"),
                                StockkeepingUnit."Location Code", StockkeepingUnit.FieldCaption("Variant Code"), StockkeepingUnit."Variant Code"), true)
                        then
                            Error('');
                end;
            until StockkeepingUnit.Next() = 0;

    end;

    local procedure CalcRequiredQty(TempSKU: Record "Stockkeeping Unit" temporary; var ItemJnlLine: Record "Item Journal Line"): Decimal
    var
        SignFactor: Integer;
        QtyinItemJnlLine: Decimal;
    begin
        QtyinItemJnlLine := 0;
        ItemJnlLine.SetCurrentKey("Journal Template Name", "Journal Batch Name", "Item No.", "Location Code", "Variant Code");
        ItemJnlLine.SetRange("Item No.", TempSKU."Item No.");
        ItemJnlLine.SetRange("Location Code", TempSKU."Location Code");
        ItemJnlLine.SetRange("Variant Code", TempSKU."Variant Code");
        ItemJnlLine.FindSet();
        repeat
            if (ItemJnlLine."Entry Type" in
                [ItemJnlLine."Entry Type"::Sale,
                 ItemJnlLine."Entry Type"::"Negative Adjmt.",
                 ItemJnlLine."Entry Type"::Consumption]) or
               (ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Transfer)
            then
                SignFactor := -1
            else
                SignFactor := 1;
            QtyinItemJnlLine += ItemJnlLine."Quantity (Base)" * SignFactor;
        until ItemJnlLine.Next() = 0;
        exit(QtyinItemJnlLine);
    end;

    local procedure SelfReservedQty(SKU: Record "Stockkeeping Unit"; ItemJnlLine: Record "Item Journal Line") Result: Decimal
    var
        ReservationEntry: Record "Reservation Entry";
        IsHandled: Boolean;
    begin
        if ItemJnlLine."Order Type" <> ItemJnlLine."Order Type"::Production then
            exit;

        with ReservationEntry do begin
            SetRange("Item No.", SKU."Item No.");
            SetRange("Location Code", SKU."Location Code");
            SetRange("Variant Code", SKU."Variant Code");
            SetRange("Source Type", Database::"Prod. Order Component");
            SetRange("Source ID", ItemJnlLine."Order No.");
            if IsEmpty() then
                exit;
            CalcSums("Quantity (Base)");
            exit(-"Quantity (Base)");
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeCreateDim', '', false, false)]
    local procedure OnBeforeCreateDimSales(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean; var DefaultDimSource: List of [Dictionary of [Integer, Code[20]]])
    begin
        If UserId = 'JOBQUEUE' Then
            IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeCreateDimensionsFromValidateSalesPersonCode', '', false, false)]
    local procedure OnBeforeCreateDimensionsFromValidateSalesPersonCode(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin

        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeSetSecurityFilterOnRespCenter', '', false, false)]
    local procedure OnBeforeSetSecurityFilterOnRespCenter(var SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        If (UserId = 'SAM4496') or (UserId = 'SAM1586') or (UserId = 'SAM4834') then
            IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Order Subform", OnInsertRecordEvent, '', true, true)]
    local procedure OnInsertRecordEvent(Rec: Record "Sales Line"; xrec: Record "Sales Line")
    var
        SalesHeader: Record "Sales Header";

    begin
        CompanyInfo.Get;
        If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
            SalesHeader.Get(Enum::"Sales Document Type"::Order, Rec."Document No.");
            SalesHeader.TestField("Location Code");
            if rec."No." <> '' then
                if Rec."Location Code" = '' then
                    Rec."Location Code" := SalesHeader."Location Code";

        end;

    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Gen. Jnl.-Check Line", 'OnAfterDateNoAllowed', '', true, true)]
    local procedure OnAfterDateNoAllowed(PostingDate: Date; var DateIsNotAllowed: Boolean)
    Var
        GLSetup: Record "General Ledger Setup";
        AllowPostingFrom: Date;
        AllowPostingTo: Date;
        SetupRecordID: RecordId;
    begin

        GLSetup.GetRecordOnce();
        GLSetup.CheckAllowedPostingDates(1);
        AllowPostingFrom := GLSetup."Allow Posting From";
        AllowPostingTo := GLSetup."Allow Posting To";
        SetupRecordID := GLSetup.RecordId;

        if AllowPostingTo = 0D then
            AllowPostingTo := DMY2Date(31, 12, 9999);
        if (PostingDate < AllowPostingFrom) or (PostingDate > AllowPostingTo) then
            DateIsNotAllowed := True;
    end;


    [EventSubscriber(ObjectType::Table, Database::"User Setup", OnAfterValidateEvent, 'Allow Posting From', true, true)]
    local procedure ValidateAllowPostingFrom(Rec: Record "User Setup")
    var
        GenledgerSetup: Record "General Ledger Setup";
    begin
        GenledgerSetup.Get();
        if GenledgerSetup."Allow Posting From" <> 0D then
            if Rec."Allow Posting From" < GenledgerSetup."Allow Posting From" then
                Error('Allowed Posting From date Can not be less than %1 due to books has been closed', GenledgerSetup."Allow Posting From");
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnBeforeAddToGlobalRecordSet', '', true, true)]
    local procedure OnBeforeAddToGlobalRecordSet(var TrackingSpecification: Record "Tracking Specification"; EntriesExist: Boolean; CurrentSignFactor: Integer; var TempTrackingSpecification: Record "Tracking Specification" temporary)
    var
        ItemTrackingSetup: Record "Item Tracking Setup";
        Mfgdate: Date;
    begin
        ItemTrackingSetup.CopyTrackingFromTrackingSpec(TrackingSpecification);
        Mfgdate := ExistingManufactringDate(TrackingSpecification."Item No.", TrackingSpecification."Variant Code", ItemTrackingSetup, false, EntriesExist);
        if Mfgdate <> 0D then
            TrackingSpecification."Manufacturing Date" := Mfgdate;


    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnCheckExpirationDateOnBeforeTestFieldExpirationDate', '', true, true)]
    local procedure OnCheckExpirationDateOnBeforeTestFieldExpirationDate(var TempTrackingSpecification: Record "Tracking Specification" temporary; var EntriesExist: Boolean; var ExistingExpirationDate: Date);
    Var
        ItemTrackingCode: Record "Item Tracking Code";
        Item: Record Item;
    begin
        Item.Get(TempTrackingSpecification."Item No.");
        ItemTrackingCode.Get(Item."Item Tracking Code");
        if ItemTrackingCode."Strict Mfg. Date Posting" then
            if not TempTrackingSpecification.Correction then
                if TempTrackingSpecification."Appl.-from Item Entry" = 0 then
                    TempTrackingSpecification.TestField("Manufacturing Date");


    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnSetupTempSplitItemJnlLineOnBeforeCalcPostItemJnlLine', '', true, true)]
    local procedure OnSetupTempSplitItemJnlLineOnBeforeCalcPostItemJnlLine(var TempSplitItemJnlLine: Record "Item Journal Line"; TempTrackingSpecification: Record "Tracking Specification")
    begin
        TempSplitItemJnlLine."Manufacturing Date" := TempTrackingSpecification."Manufacturing Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnBeforeTempHandlingSpecificationInsert', '', true, true)]
    local procedure OnBeforeTempHandlingSpecificationInsert(var TempTrackingSpecification: Record "Tracking Specification" temporary; ReservationEntry: Record "Reservation Entry"; var ItemTrackingCode: Record "Item Tracking Code"; var EntriesExist: Boolean)
    var
        ItemTrackingSetup: Record "Item Tracking Setup";

    begin
        if ItemTrackingCode."Use Expiration Dates" then begin
            ItemTrackingSetup.CopyTrackingFromReservEntry(ReservationEntry);
            if EntriesExist then
                TempTrackingSpecification."Manufacturing Date" := ExistingManufactringDate(ReservationEntry."Item No.", ReservationEntry."Variant Code", ItemTrackingSetup, false, EntriesExist);
            ;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse.-Activity-Register", 'OnBeforeWhseJnlRegisterLine', '', true, true)]
    local procedure OnBeforeWhseJnlRegisterLine(var WarehouseJournalLine: Record "Warehouse Journal Line"; WarehouseActivityLine: Record "Warehouse Activity Line")
    begin
        WarehouseJournalLine."Manufacturing Date" := WarehouseActivityLine."Manufacturing Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Pick", 'OnAfterTransferItemTrkgFields', '', true, true)]
    local procedure OnAfterTransferItemTrkgFields(var WarehouseActivityLine: Record "Warehouse Activity Line"; WhseItemTrackingLine: Record "Whse. Item Tracking Line")
    var
        ManufacturingDate: Date;
        ItemTrackingSetup: Record "Item Tracking Setup";
        EntriesExist: Boolean;

    begin
        if WhseItemTrackingLine.TrackingExists() then begin
            ItemTrackingSetup.CopyTrackingFromWhseActivityLine(WarehouseActivityLine);
            ManufacturingDate := 0D;
            if WarehouseActivityLine."Expiration Date" <> 0D then begin
                ManufacturingDate := ExistingManufactringDate(WarehouseActivityLine."Item No.", WarehouseActivityLine."Variant Code", ItemTrackingSetup, false, EntriesExist);
                WarehouseActivityLine."Manufacturing Date" := ManufacturingDate;
            end;
        end else
            if not EntriesExist then
                WarehouseActivityLine."Manufacturing Date" := WhseItemTrackingLine."Manufacturing Date";

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnSplitWhseJnlLineOnAfterCopyTrackingByToTransfer', '', true, true)]
    local procedure OnSplitWhseJnlLineOnAfterCopyTrackingByToTransfer(ToTransfer: Boolean; var TempWhseJnlLine2: Record "Warehouse Journal Line"; var TempWhseSplitTrackingSpec: Record "Tracking Specification")
    begin
        if ToTransfer then begin
            if TempWhseSplitTrackingSpec."New Manufacturing Date" <> 0D then
                TempWhseJnlLine2."Manufacturing Date" := TempWhseSplitTrackingSpec."New Manufacturing Date"
            else
                TempWhseJnlLine2."Manufacturing Date" := TempWhseSplitTrackingSpec."Manufacturing Date";
        end else
            TempWhseJnlLine2."Manufacturing Date" := TempWhseSplitTrackingSpec."Manufacturing Date";

        TempWhseJnlLine2."New Manufacturing Date" := TempWhseSplitTrackingSpec."New Manufacturing Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnBeforeInsertWhseItemTrkgLines', '', true, true)]
    local procedure OnBeforeInsertWhseItemTrkgLines(var WhseItemTrkgLine: Record "Whse. Item Tracking Line"; PostedWhseReceiptLine: Record "Posted Whse. Receipt Line"; WhseItemEntryRelation: Record "Whse. Item Entry Relation"; ItemLedgerEntry: Record "Item Ledger Entry")
    begin
        if WhseItemTrkgLine."Expiration Date" <> 0D then
            WhseItemTrkgLine."Manufacturing Date" := ItemLedgerEntry."Manufacturing Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse. Jnl.-Register Line", 'OnInitWhseEntryCopyFromWhseJnlLine', '', true, true)]
    local procedure OnInitWhseEntryCopyFromWhseJnlLine(var WarehouseEntry: Record "Warehouse Entry"; var WarehouseJournalLine: Record "Warehouse Journal Line")
    begin
        WarehouseEntry."Manufacturing Date" := WarehouseJournalLine."Manufacturing Date";
        //WarehouseEntry."Expiration Date" := WarehouseJournalLine."Expiration Date";

        if (WarehouseJournalLine."New Manufacturing Date" <> WarehouseJournalLine."Manufacturing Date") and
        (WarehouseEntry."Entry Type" = WarehouseEntry."Entry Type"::Movement) and
         (WarehouseJournalLine."New Manufacturing Date" <> 0D) then
            WarehouseEntry."Manufacturing Date" := WarehouseJournalLine."New Manufacturing Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Whse. Jnl.-Register Batch", 'OnCreateItemJnlLineOnAfterCalcShouldCreateReservEntry', '', true, true)]
    local procedure OnCreateItemJnlLineOnAfterCalcShouldCreateReservEntry(var ShouldCreateReservEntry: Boolean; WhseItemTrackingLine: Record "Whse. Item Tracking Line")
    begin
        ShouldCreateReservEntry := not WhseItemTrackingLine.HasSameNewTracking() or
                        (WhseItemTrackingLine."New Expiration Date" <> WhseItemTrackingLine."Expiration Date") or
                        (WhseItemTrackingLine."New Manufacturing Date" <> WhseItemTrackingLine."Manufacturing Date");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnAfterInitReservEntry', '', true, true)]
    local procedure OnAfterInitReservEntry(var ReservEntry: Record "Reservation Entry"; ItemLedgerEntry: Record "Item Ledger Entry")
    var
        ItemTrackingSetup: Record "Item Tracking Setup";
        EntriesExist: Boolean;
    begin
        ItemTrackingSetup.CopyTrackingFromItemLedgerEntry(ItemLedgerEntry);
        if ReservEntry.Positive then begin
            ReservEntry."Manufacturing Date" := ExistingManufactringDate(ItemLedgerEntry."Item No.", ItemLedgerEntry."Variant Code", ItemTrackingSetup, false, EntriesExist);
        end;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Management", 'OnAfterRetrieveAppliedExpirationDate', '', true, true)]
    local procedure OnAfterRetrieveAppliedExpirationDate(var TempItemLedgEntry: Record "Item Ledger Entry" temporary; ItemApplicationEntry: Record "Item Application Entry")
    var
        ItemLedgEntry: record "Item Ledger Entry";
    begin
        ItemLedgEntry.Get(ItemApplicationEntry."Inbound Item Entry No.");
        TempItemLedgEntry."Expiration Date" := ItemLedgEntry."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnSetupSplitJnlLineOnAfterCheckExpirationDate', '', true, true)]
    local procedure OnSetupSplitJnlLineOnAfterCheckExpirationDate(var ItemJnlLine2: Record "Item Journal Line"; var TempTrackingSpecification: Record "Tracking Specification" temporary; Item: Record Item)
    var
        ItemTrackingSetup: Record "Item Tracking Setup";
        EntriesExist: Boolean;
    begin
        ItemTrackingSetup.CopyTrackingFromTrackingSpec(tempTrackingSpecification);
        if (ItemJnlLine2."Order Type" = ItemJnlLine2."Order Type"::Transfer) and
                   (ItemJnlLine2."Order No." <> '')
                then
            if TempTrackingSpecification."New Manufacturing Date" = 0D then
                TempTrackingSpecification."New Manufacturing Date" := ExistingManufactringDate(TempTrackingSpecification."Item No.", TempTrackingSpecification."Variant Code", ItemTrackingSetup, True, EntriesExist);

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnInsertTransferEntryOnTransferValues', '', true, true)]
    local procedure OnInsertTransferEntryOnTransferValues(ItemJournalLine: Record "Item Journal Line"; var NewItemLedgerEntry: Record "Item Ledger Entry")
    begin

        NewItemLedgerEntry."Manufacturing Date" := ItemJournalLine."New Manufacturing Date";

    end;

    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", 'OnAfterInitExpirationDate', '', true, true)]
    local procedure OnAfterInitExpirationDate(var TrackingSpecification: Record "Tracking Specification")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemTrackingSetup: Record "Item Tracking Setup";
        ItemTrackingManagement: Codeunit "Item Tracking Management";
    begin
        // if (TrackingSpecification."Source Type" = 37) and (TrackingSpecification."Source Subtype" = 1) then begin
        ItemTrackingSetup."Serial No." := TrackingSpecification."Serial No.";
        ItemTrackingSetup."Lot No." := TrackingSpecification."Lot No.";

        if ItemTrackingManagement.FindLastItemLedgerEntry(TrackingSpecification."Item No.", TrackingSpecification."Variant Code", ItemTrackingSetup, ItemLedgerEntry) then begin
            TrackingSpecification."Manufacturing Date" := ItemLedgerEntry."Manufacturing Date";
            if TrackingSpecification.IsReclass() then begin
                TrackingSpecification."New Manufacturing Date" := ItemLedgerEntry."Manufacturing Date";
            end;

        end;


        //end;
        TrackingSpecification."Buffer Status2" := 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Data Collection", 'OnTransferItemLedgToTempRecOnBeforeInsert', '', true, true)]
    local procedure OnTransferItemLedgToTempRecOnBeforeInsert(ItemLedgerEntry: Record "Item Ledger Entry"; var TempGlobalReservEntry: Record "Reservation Entry")
    begin
        TempGlobalReservEntry."Manufacturing Date" := ItemLedgerEntry."Manufacturing Date";
        TempGlobalReservEntry."New Manufacturing Date" := ItemLedgerEntry."Manufacturing Date";
        //TempGlobalReservEntry."Expiration Date" := ItemLedgerEntry."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterCopyTrackingSpec', '', true, true)]
    local procedure OnAfterCopyTrackingSpec(var DestTrkgSpec: Record "Tracking Specification"; var SourceTrackingSpec: Record "Tracking Specification")
    var

    begin
        DestTrkgSpec."Manufacturing Date" := SourceTrackingSpec."Manufacturing Date";
        //DestTrkgSpec."Expiration Date" := SourceTrackingSpec."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Reservation Entry", 'OnAfterCopyTrackingFromTrackingSpec', '', true, true)]
    local procedure OnAfterCopyTrackingFromTrackingSpec(TrackingSpecification: Record "Tracking Specification"; var ReservationEntry: Record "Reservation Entry")
    begin
        ReservationEntry."Manufacturing Date" := TrackingSpecification."Manufacturing Date";
        //ReservationEntry."Expiration Date" := TrackingSpecification."Expiration Date";//WIN560 3/10/23 
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Tracking Data Collection", 'OnCreateEntrySummary2OnBeforeInsertOrModify', '', true, true)]
    local procedure OnCreateEntrySummary2OnBeforeInsertOrModify(TempGlobalEntrySummary: Record "Entry Summary" temporary; TempReservEntry: Record "Reservation Entry" temporary)
    begin
        if TempReservEntry.Positive then begin
            TempGlobalEntrySummary."Manufacturing Date" := TempReservEntry."Manufacturing Date";
            TempGlobalEntrySummary."New Manufacturing Date" := TempReservEntry."New Manufacturing Date";
            //TempGlobalEntrySummary."Expiration Date" := TempReservEntry."Expiration Date";
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnRegisterChangeOnAfterCreateReservEntry', '', false, false)]
    local procedure ItemTrackingLinesOnRegisterChangeOnAfterCreateReservEntry(var ReservEntry: Record "Reservation Entry"; OldTrackingSpecification: Record "Tracking Specification")
    begin
        ReservEntry."Manufacturing Date" := OldTrackingSpecification."Manufacturing Date";
        ReservEntry."New Manufacturing Date" := OldTrackingSpecification."New Manufacturing Date";
        //ReservEntry."Expiration Date" := OldTrackingSpecification."Expiration Date";
        ReservEntry.Modify();
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterCopyTrackingSpec', '', false, false)]
    local procedure ItemTrackingLinesOnAfterCopyTrackingSpec(var DestTrkgSpec: Record "Tracking Specification"; var SourceTrackingSpec: Record "Tracking Specification")
    begin
        DestTrkgSpec."Manufacturing Date" := SourceTrackingSpec."Manufacturing Date";
        DestTrkgSpec."New Manufacturing Date" := SourceTrackingSpec."New Manufacturing Date";
        //DestTrkgSpec."Expiration Date" := SourceTrackingSpec."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterEntriesAreIdentical', '', false, false)]
    local procedure ItemTrackingLinesOnAfterEntriesAreIdentical(ReservEntry1: Record "Reservation Entry"; ReservEntry2: Record "Reservation Entry"; var IdenticalArray: array[2] of Boolean)
    begin

        IdenticalArray[2] := IdenticalArray[2] and (ReservEntry1."Manufacturing Date" = ReservEntry2."Manufacturing Date");
    end;

    [EventSubscriber(ObjectType::Page, Page::"Item Tracking Lines", 'OnAfterMoveFields', '', false, false)]
    local procedure ItemTrackingLinesOnAfterMoveFields(var ReservEntry: Record "Reservation Entry"; var TrkgSpec: Record "Tracking Specification")
    begin
        ReservEntry."Manufacturing Date" := TrkgSpec."Manufacturing Date";
        ReservEntry."New Manufacturing Date" := TrkgSpec."New Manufacturing Date";
        //ReservEntry."Expiration Date" := TrkgSpec."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertSetupTempSplitItemJnlLine', '', false, false)]
    local procedure ItemJnlPostLineOnBeforeInsertSetupTempSplitItemJnlLine(var TempTrackingSpecification: Record "Tracking Specification"; var TempItemJournalLine: Record "Item Journal Line"; var PostItemJnlLine: Boolean)
    begin
        TempItemJournalLine."Manufacturing Date" := TempTrackingSpecification."Manufacturing Date";
        TempItemJournalLine."New Manufacturing Date" := TempTrackingSpecification."New Manufacturing Date";
        //TempItemJournalLine."Expiration Date" := TempTrackingSpecification."Expiration Date";

        PostItemJnlLine := not TempItemJournalLine.HasSameNewTracking() or (TempItemJournalLine."Item Expiration Date" <> TempItemJournalLine."New Item Expiration Date") or
        (TempItemJournalLine."Manufacturing Date" <> TempItemJournalLine."New Manufacturing Date");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    local procedure ItemJnlPostLineOnAfterInitItemLedgEntry(var NewItemLedgEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line")
    begin
        NewItemLedgEntry."Manufacturing Date" := ItemJournalLine."Manufacturing Date";
        //NewItemLedgEntry."Expiration Date" := ItemJournalLine."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Create Reserv. Entry", 'OnAfterSetNewTrackingFromNewWhseItemTrackingLine', '', true, true)]
    local procedure OnAfterSetNewTrackingFromNewWhseItemTrackingLine(var InsertReservEntry: Record "Reservation Entry"; WhseItemTrackingLine: Record "Whse. Item Tracking Line")
    begin
        InsertReservEntry."Manufacturing Date" := WhseItemTrackingLine."Manufacturing Date";
        InsertReservEntry."New Manufacturing Date" := WhseItemTrackingLine."New Manufacturing Date";
        //InsertReservEntry."Expiration Date" := WhseItemTrackingLine."Expiration Date";
    end;

    [EventSubscriber(ObjectType::Table, Database::"Tracking Specification", 'OnAfterCopyTrackingFromEntrySummary', '', true, true)]
    local procedure OnAfterCopyTrackingFromEntrySummary(EntrySummary: Record "Entry Summary"; var TrackingSpecification: Record "Tracking Specification")
    begin
        TrackingSpecification."Manufacturing Date" := EntrySummary."Manufacturing Date";
        TrackingSpecification."New Manufacturing Date" := EntrySummary."New Manufacturing Date";
        //TrackingSpecification."Expiration Date" := EntrySummary."Expiration Date";
    end;



    procedure ExistingManufactringDate(ItemNo: Code[20]; VariantCode: Code[20]; ItemTrackingSetup: Record "Item Tracking Setup"; TestMultiple: Boolean; var EntriesExist: Boolean) ManufacturingDate: Date
    var
        ItemLedgEntry: Record "Item Ledger Entry";
        ItemTracingMgt: Codeunit "Item Tracing Mgt.";
        IsHandled: Boolean;
        ItemTracMgt: Codeunit "Item Tracking Management";
    begin


        ItemLedgEntry.SetLoadFields("Manufacturing Date");
        if not ItemTracMgt.FindLastItemLedgerEntry(ItemNo, VariantCode, ItemTrackingSetup, ItemLedgEntry) then begin
            EntriesExist := false;
            exit;
        end;

        EntriesExist := true;
        ManufacturingDate := ItemLedgEntry."Manufacturing Date";

        if TestMultiple and ItemTracingMgt.IsSpecificTracking(ItemNo, ItemTrackingSetup) then begin
            ItemLedgEntry.SetFilter("Manufacturing Date", '<>%1', ItemLedgEntry."Manufacturing Date");
            ItemLedgEntry.SetRange(Open, true);
            if not ItemLedgEntry.IsEmpty() then
                Error(Text007, ItemTrackingSetup."Lot No.");
        end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Transfer Order", OnBeforeValidateEvent, 'Transfer-to Code', true, true)]
    local procedure OnBeforeValidateEventTransfertoCode(Rec: Record "Transfer Header")
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get;
        if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
            if Rec."Transfer-to Code" = 'SFPL0137' then
                if ((Rec."Transfer-from Code" <> 'SFPL0093') and (Rec."Transfer-from Code" <> 'SFPL0093-P')) then
                    Error('You can make transfer entry only from SFPL0093 and SFPL0093-P Location');

            if Rec."Transfer-from Code" = 'SFPL0137' then
                if ((Rec."Transfer-to Code" <> 'SFPL0093')) then
                    Error('You can make transfer entry only from SFPL0093 and SFPL0093-P Location');
        end;


    end;

    [EventSubscriber(ObjectType::Page, Page::"Transfer Order", OnBeforeValidateEvent, 'Transfer-From Code', true, true)]
    local procedure OnBeforeValidateEventTransferFromCode(Rec: Record "Transfer Header")
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get;
        if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
            if rec."Transfer-to Code" <> '' then
                if Rec."Transfer-to Code" = 'SFPL0137' then
                    if ((Rec."Transfer-from Code" <> 'SFPL0093') and (Rec."Transfer-from Code" <> 'SFPL0093-P')) then
                        Error('You can make transfer entry only from SFPL0093 and SFPL0093-P Location');

            if rec."Transfer-to Code" <> '' then
                if Rec."Transfer-from Code" = 'SFPL0137' then
                    if ((Rec."Transfer-to Code" <> 'SFPL0093')) then
                        Error('You can make transfer entry only from SFPL0093 and SFPL0093-P Location');
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", OnBeforeValidateEvent, 'Location Code', False, false)]
    local procedure TDSThreshoildCalculation(rec: Record "Purchase Header")
    var
        LOcation: record Location;
    begin
        if Rec."Location Code" <> '' Then begin
            LOcation.Get(Rec."Location Code");
            if LOcation.Block then
                Error('The %1 Location Code is blocked', Rec."Location Code");
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", OnAfterInsertPostedHeaders, '', true, true)]
    local procedure OnAfterInsertPostedHeaders(var SalesHeader: Record "Sales Header"; var SalesShipmentHeader: Record "Sales Shipment Header"; var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesCrMemoHdr: Record "Sales Cr.Memo Header"; var ReceiptHeader: Record "Return Receipt Header")
    begin
        if SalesShipmentHeader."No." <> '' then begin
            SalesShipmentHeader."Shiiping From" := SalesHeader."Shiiping From";
            SalesShipmentHeader.Modify();
        end;
        if SalesInvoiceHeader."No." <> '' then begin
            SalesInvoiceHeader."Shiiping From" := SalesHeader."Shiiping From";
            SalesInvoiceHeader.Modify();
        end;
        if SalesCrMemoHdr."No." <> '' then begin
            SalesCrMemoHdr."Shiiping From" := SalesHeader."Shiiping From";
            SalesCrMemoHdr.Modify();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeOnRun', '', true, true)]

    local procedure OnBeforeOnRun(var TransferHeader2: Record "Transfer Header"; var HideValidationDialog: Boolean; SuppressCommit: Boolean; var IsHandled: Boolean)
    var
        TransferShipment: Record "Transfer Shipment Header";
        CompanyInfo: Record "Company Information";
    Begin
        CompanyInfo.Get;
        if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
            TransferShipment.Reset();
            TransferShipment.SetRange("Transfer Order No.", TransferHeader2."No.");
            if TransferShipment.FindFirst() then
                if TransferHeader2."Posting Date" < TransferShipment."Posting Date" then
                    Error('You can not post tranfer receipt on before shipment posting date, Shipment posting date is %1', TransferShipment."Posting Date");
        end;
    End;


    [EventSubscriber(ObjectType::Table, Database::"Salesperson/Purchaser", OnAfterValidateEvent, 'E-Mail', false, false)]
    local procedure ValidateEmailIDonSalesPerson(Rec: Record "Salesperson/Purchaser")
    var
        AllowedDomains: List of [Text];
        Domain: Text;
        LowerEmail: Text;
        IsValid: Boolean;
    begin
        if Rec."E-Mail" <> '' then begin
            AllowedDomains.Add('@sampoornafeeds.in');
            AllowedDomains.Add('@sampoornafeeds.com');
            AllowedDomains.Add('@starfood.co.in');

            LowerEmail := LowerCase(Rec."E-Mail");
            IsValid := false;

            foreach Domain in AllowedDomains do begin
                if StrPos(LowerEmail, Domain) > 0 then begin
                    IsValid := true;
                    break;
                end;
            end;

            if not IsValid then
                Error('Please update with a valid organization email. Personal email IDs are not allowed.');
        end;

    end;

    [EventSubscriber(ObjectType::Table, Database::Team, OnAfterValidateEvent, 'E-Mail', false, false)]
    local procedure ValidateEmailIDonSalesTeam(Rec: Record Team)
    var
        AllowedDomains: List of [Text];
        Domain: Text;
        LowerEmail: Text;
        IsValid: Boolean;
    begin
        if Rec."E-Mail" <> '' then begin
            AllowedDomains.Add('@sampoornafeeds.in');
            AllowedDomains.Add('@sampoornafeeds.com');
            AllowedDomains.Add('@starfood.co.in');

            LowerEmail := LowerCase(Rec."E-Mail");
            IsValid := false;

            foreach Domain in AllowedDomains do begin
                if StrPos(LowerEmail, Domain) > 0 then begin
                    IsValid := true;
                    break;
                end;
            end;

            if not IsValid then
                Error('Please update with a valid organization email. Personal email IDs are not allowed.');
        end;

    end;



    [EventSubscriber(ObjectType::Table, Database::"Ship-to Address", OnBeforeValidateEvent, 'Phone No.', True, True)]
    local procedure OnBeforeValidateEventPhoneNo(Var Rec: record "Ship-to Address")
    begin
        if rec."Phone No.".StartsWith('+91') then
            Error('Can not start with +91 in Mobile No.');
        if rec."Phone No.".StartsWith('0') then
            Error('Can not start with 0 in Mobile No.');
        if (StrPos(Rec."Phone No.", '-')) > 0 then
            Error('No hyphen in phone number.');
        if (StrPos(Rec."Phone No.", ' ')) > 0 then
            Error('No space in phone number.');
        if StrLen(Rec."Phone No.") < 10 then
            Error('Phone No. Must be Minimum 10 Digit');
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnBeforeValidateEvent, 'Phone No.', True, True)]
    local procedure OnBeforeValidateEventCustomerPhoneNo(Var Rec: record Customer)
    begin

        if rec."Phone No.".StartsWith('+91') then
            Error('Can not start with +91 in Mobile No.');
        if rec."Phone No.".StartsWith('0') then
            Error('Can not start with 0 in Mobile No.');
        if (StrPos(Rec."Phone No.", '-')) > 0 then
            Error('No hyphen in phone number.');
        if (StrPos(Rec."Phone No.", ' ')) > 0 then
            Error('No Space in phone number.');
        if Rec."Phone No." <> '' then
            if StrLen(Rec."Phone No.") < 10 then
                Error('Phone No. Must be Minimum 10 Digit');
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnBeforeValidateEvent, 'Mobile Phone No.', True, True)]
    local procedure OnBeforeValidateEventCustomerMobilePhoneNo(Var Rec: record Customer)
    begin
        if rec."Mobile Phone No.".StartsWith('+91') then
            Error('Can not start with +91 in Mobile No.');
        if rec."Mobile Phone No.".StartsWith('0') then
            Error('Can not start with 0 in Mobile No.');
        if (StrPos(Rec."Mobile Phone No.", '-')) > 0 then
            Error('No hyphen in phone number.');
        if (StrPos(Rec."Mobile Phone No.", ' ')) > 0 then
            Error('No space in phone number.');
        if rec."Mobile Phone No." <> '' Then
            if StrLen(Rec."Mobile Phone No.") < 10 then
                Error('Mobile Phone No. Must be Minimum 10 Digit');
    end;

    [EventSubscriber(ObjectType::Table, Database::Customer, OnBeforeValidateEvent, 'WhatsApp Mobile No.', True, True)]
    local procedure OnBeforeValidateEventCustomerWhatsAppMobileNo(Var Rec: record Customer)
    begin
        if rec."WhatsApp Mobile No.".StartsWith('+91') then
            Error('Can not start with +91 in Mobile No.');
        if rec."WhatsApp Mobile No.".StartsWith('0') then
            Error('Can not start with 0 in Mobile No.');
        if (StrPos(Rec."WhatsApp Mobile No.", '-')) > 0 then
            Error('No hyphen in phone number.');
        if (StrPos(Rec."WhatsApp Mobile No.", ' ')) > 0 then
            Error('No space in phone number.');
        if Rec."WhatsApp Mobile No." <> '' Then
            if StrLen(Rec."WhatsApp Mobile No.") < 10 then
                Error('WhatsApp Mobile No. Must be Minimum 10 Digit');
    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Purchase Line", 'OnafterValidateEvent', 'No.', false, false)]
    local procedure OnafterValidateEventNo_(Var Rec: Record "Purchase Line")
    var
        RecItem: Record Item;
    begin
        If Rec.type = Rec.Type::Item then
            if Rec."No." <> '' Then begin
                RecItem.Get(Rec."No.");
                Rec."Item Type" := RecItem."Item Type";

            end;
    end;


    [EventSubscriber(ObjectType::Table, DataBase::"Purchase Header", 'OnAfterInitRecord', '', false, false)]
    local procedure OnAfterInitRecord(var PurchHeader: Record "Purchase Header")
    var
        Companyinfo: Record "Company Information";
    begin
        Companyinfo.get;
        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then
            if PurchHeader."Document Type" = PurchHeader."Document Type"::Order then
                if PurchHeader."No. Series" = 'PO' then
                    PurchHeader.Validate("PO Type", PurchHeader."PO Type"::Goods)
                else
                    PurchHeader.Validate("PO Type", PurchHeader."PO Type"::Service);

    end;

    [EventSubscriber(ObjectType::Page, Page::"Vendor Card", 'OnClosePageEvent', '', false, false)]
    local procedure OnClosePageEventVendorCard(var Rec: Record Vendor)
    var
        VendBankAccount: record "Vendor Bank Account";
        Companyinfo: Record "Company Information";
    begin
        Companyinfo.Get;
        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then
            If Rec."Vendor Posting Group" = 'DOMESTIC' then begin
                VendBankAccount.Reset();
                VendBankAccount.SetRange("Vendor No.", Rec."No.");
                if VendBankAccount.FindFirst() then
                    repeat
                        if VendBankAccount."Bank Account No." = '' then begin
                            Rec.Blocked := Rec.Blocked::All;
                            Rec.Modify();
                        end else
                            If VendBankAccount."IFSC Code" = '' then begin
                                Rec.Blocked := Rec.Blocked::All;
                                Rec.Modify();
                            end else begin
                                Rec.Blocked := Rec.Blocked::" ";
                                Rec.Modify();
                            end;
                    until VendBankAccount.Next() = 0;
            end;
        // if rec."Preferred Bank Account Code" = '' then begin
        //     Rec.Blocked := Rec.Blocked::All;
        //     Rec.Modify();
        // end else begin
        //     VendBankAccount.Get(Rec."No.", Rec."Preferred Bank Account Code");
        //     if VendBankAccount."Bank Account No." = '' Then begin
        //         Rec.Blocked := Rec.Blocked::All;
        //         Rec.Modify();
        //     end else begin
        //         Rec.Blocked := Rec.Blocked::" ";
        //         Rec.Modify();
        //     end;
        // end;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnbeforeValidateEvent', 'Due Date calculation', false, false)]
    local procedure OnValidateEventDueDatecalculation(Var Rec: Record "Purchase Header")
    var
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get;
        If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] Then
            If Rec."Due Date calculation" = Rec."Due Date calculation"::"Document Date" then
                Error('Can not Select the Document Date, Only Posting date allowed');
    end;

    [EventSubscriber(ObjectType::Table, Database::"TDS Journal Line", 'OnAfterValidateEvent', 'TDS % Applied', false, false)]
    local procedure OnAfterValidateEventTransactionNo(var Rec: Record "TDS Journal Line")
    var
        RecVendLedger: Record "Vendor Ledger Entry";
        TDSEntry: Record "TDS Entry";
    begin
        TDSEntry.Get(Rec."TDS Transaction No.");
        RecVendLedger.Reset();
        RecVendLedger.SetRange("Document No.", TDSEntry."Document No.");
        If RecVendLedger.FindFirst() then begin
            Rec.Validate("Shortcut Dimension 1 Code", RecVendLedger."Global Dimension 1 Code");
            Rec.Validate("Shortcut Dimension 2 Code", RecVendLedger."Global Dimension 2 Code");
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, 1312, 'OnAfterSetFilterForExternalDocNo', '', false, false)]
    local procedure OnAfterSetFilterForExternalDocNo(var VendorLedgerEntry: Record "Vendor Ledger Entry"; DocumentDate: Date);
    var
        F_StartDate1: Date;
        F_EndDate1: Date;
        TempYear: Integer;
        TempMonth: Integer;
    begin

        CLEAR(F_StartDate1);
        CLEAR(F_EndDate1);

        CLEAR(TempYear);
        CLEAR(TempMonth);
        TempYear := DATE2DMY(DocumentDate, 3);
        TempMonth := DATE2DMY(DocumentDate, 2);
        IF (TempMonth = 1) OR (TempMonth = 2) OR (TempMonth = 3) THEN BEGIN
            F_StartDate1 := DMY2DATE(1, 4, (TempYear - 1));
            F_EndDate1 := DMY2DATE(31, 3, (TempYear));
        END ELSE BEGIN
            F_StartDate1 := DMY2DATE(1, 4, (TempYear));
            F_EndDate1 := DMY2DATE(31, 3, (TempYear + 1));
        END;

        IF (F_StartDate1 <> 0D) AND (F_EndDate1 <> 0D) THEN     //PRU_RPG 26Sept2018
            VendorLedgerEntry.SETRANGE("Posting Date", F_StartDate1, F_EndDate1);

    end;


    [EventSubscriber(ObjectType::Table, 83, 'OnSelectItemEntryOnBeforeOpenPage', '', false, false)]
    local procedure OnSelectItemEntryOnBeforeOpenPage(var ItemLedgerEntry: Record "Item Ledger Entry"; ItemJournalLine: Record "Item Journal Line"; CurrentFieldNo: Integer);
    var
    begin

        if ItemJournalLine.Consumption = True then
            if CurrentFieldNo <> 29 Then
                ItemLedgerEntry.SetRange(Consumption, true);
    end;

    [EventSubscriber(ObjectType::Codeunit, 241, 'OnBeforeCode', '', false, false)]
    local procedure OnBeforeCodeItemJournal(var ItemJournalLine: Record "Item Journal Line"; var HideDialog: Boolean; var SuppressCommit: Boolean; var IsHandled: Boolean);
    var
        DimensionMaster: Record "Dimension Master";
        DimnErr: Label 'Dimension Master Does not exist for Document No %1 and Line No. %2.';
        CompanyInfo: record "Company Information";
    begin
        CompanyInfo.Get;
        if ItemJournalLine.Consumption = True then
            if ItemJournalLine."Entry Type" = ItemJournalLine."Entry Type"::"Positive Adjmt." then
                ItemJournalLine.TestField("Applies-from Entry");
        if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] Then Begin
            DimensionMaster.RESET;
            DimensionMaster.SETRANGE("Shortcut Dimension 1 Code", ItemJournalLine."Shortcut Dimension 1 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 2 Code", ItemJournalLine."Shortcut Dimension 2 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 3 Code", ItemJournalLine."Shortcut Dimension 3 Code");
            IF NOT DimensionMaster.FINDFIRST THEN
                ERROR(DimnErr, ItemJournalLine."Document No.", ItemJournalLine."Line No.");
        End;

    end;


    [EventSubscriber(ObjectType::Table, 39, 'OnBeforeGetDeferralAmount', '', false, false)]
    local procedure UpdateDeferralAmount(var PurchaseLine: Record "Purchase Line"; var DeferralAmount: Decimal; var IsHandled: Boolean);
    var
        GSTBOOL: Boolean;
        SgstAmount: Decimal;
        CgstAmount: Decimal;
        IgstAmount: Decimal;
        GSTSetup1: Record "GST Setup";
        TaxTransValue1: Record "Tax Transaction Value";
        TaxComponentName1: Text;
        SgstPer: Decimal;
        CgstPer: Decimal;
        IgstPer: Decimal;
        SGST_Amt2: Decimal;
        IGST_Amt2: Decimal;
        CGST_Amt2: Decimal;
        GSTamt1: Decimal;
    begin

        Clear(IgstAmount);
        Clear(CgstAmount);
        Clear(SgstAmount);
        GSTSetup1.Get();//PT
        TaxTransValue1.SetRange("Tax Type", GSTSetup1."GST Tax Type");
        TaxTransValue1.SetRange("Tax Record ID", PurchaseLine.RecordId());
        TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
        TaxTransValue1.SetFilter(Percent, '<>%1', 0);
        if TaxTransValue1.FindSet() then
            repeat
                TaxComponentName1 := TaxTransValue1.GetAttributeColumName();
                case TaxComponentName1 of
                    'IGST':
                        begin
                            IgstPer := TaxTransValue1.Percent;
                            evaluate(IGST_Amt2, TaxTransValue1."Column Value");
                            IgstAmount += IGST_Amt2;
                        end;
                    'CGST':
                        begin
                            evaluate(CGST_Amt2, TaxTransValue1."Column Value");
                            CgstPer += TaxTransValue1.Percent;
                            CgstAmount += CGST_Amt2;
                        end;
                    'SGST':
                        begin
                            evaluate(SGST_Amt2, TaxTransValue1."Column Value");
                            SgstPer += TaxTransValue1.Percent;
                            SgstAmount += SGST_Amt2;
                        end;
                end;
            until TaxTransValue1.Next() = 0;

        IF IgstAmount <> 0 THEN BEGIN
            GSTBOOL := TRUE;
        END;
        IF CgstAmount <> 0 THEN BEGIN
            GSTBOOL := FALSE;
        END;
        GSTamt1 := IgstAmount + CgstAmount + SgstAmount;

        if PurchaseLine."GST Credit" = PurchaseLine."GST Credit"::"Non-Availment" then Begin
            IsHandled := True;
            DeferralAmount := PurchaseLine."Line Amount" + GSTamt1;
        End;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostUpdateOrderLineOnSetDefaultQtyBlank', '', false, false)]
    local procedure OnPostUpdateOrderLineOnSetDefaultQtyBlank(var PurchaseHeader: Record "Purchase Header"; var TempPurchaseLine: Record "Purchase Line" temporary; PurchPost: Record "Purchases & Payables Setup"; var SetDefaultQtyBlank: Boolean)
    begin
        CompanyInfo.Get;

        if SetDefaultQtyBlank then begin
            TempPurchaseLine."Challan Qty" := 0;
            TempPurchaseLine."Weight Qty" := 0;
            TempPurchaseLine."Actual Qty." := 0;
        end;


    end;

    [EventSubscriber(ObjectType::Page, 18554, 'OnBeforeValidateEvent', 'Amount', false, false)]
    local procedure OnBeforevalidateAmt(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin

        if Rec."Source Code" = 'CASHPYMTV' Then begin
            If Rec."Line No." <> 0 Then
                Rec.TestField("Document Type");
            if ABS(Rec.Amount) > 10000 then
                Error(Text001, '10,000');
        end;

        if Rec."Source Code" = 'CASHRCPTV' Then begin
            If Rec."Line No." <> 0 Then
                Rec.TestField("Document Type");
            if rec.Amount <> 0 Then
                if ABS(Rec.Amount) > 200000 then
                    Error(Text001, '2,00,000');
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnBeforeValidateEvent', 'Location Code', false, false)]
    local procedure OnBeforevalidateLocationCode(var Rec: Record "Sales Line")
    var

    begin
        Rec.Validate("Flock No.", '');
    end;

    [EventSubscriber(ObjectType::Table, 37, 'OnBeforeValidateEvent', 'FOC', false, false)]
    local procedure OnBeforevalidateFOC(var Rec: Record "Sales Line")
    var

    begin
        If Rec.Exempted = false then
            Error('You can not select as FOC');
    end;

    [EventSubscriber(ObjectType::Page, 18554, 'OnBeforeValidateEvent', 'Debit Amount', false, false)]
    local procedure OnBeforevalidateDebitAmt(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        if Rec."Source Code" = 'CASHPYMTV' Then begin
            if ABS(Rec.Amount) > 10000 then
                Error(Text001, '10,000');
        end;

        if Rec."Source Code" = 'CASHRCPTV' Then begin
            if ABS(Rec.Amount) > 200000 then
                Error(Text001, '2,00,000');
        end;
    end;

    [EventSubscriber(ObjectType::Page, 18554, 'OnBeforeValidateEvent', 'Credit Amount', false, false)]
    local procedure OnBeforevalidateCreditAmt(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        if Rec."Source Code" = 'CASHPYMTV' Then begin
            Rec.TestField("Document Type");
            if ABS(Rec.Amount) > 10000 then
                Error(Text001, '10,000');
        end;
        if Rec."Source Code" = 'CASHRCPTV' Then begin
            Rec.TestField("Document Type");
            if ABS(Rec.Amount) > 200000 then
                Error(Text001, '2,00,000');
        end;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Location Card", 'OnClosePageEvent', '', false, False)]
    local procedure RegionCodeMandatory(Var Rec: Record Location)
    begin
        If Rec."Global Dimension 1 Code" in ['CBF'] then
            Rec.TestField(Rec."Region Code");
    end;

    [EventSubscriber(ObjectType::Table, 14, 'OnafterValidateevent', 'Global Dimension 2 Code', false, False)]
    local procedure RegionCodeUpdate(Var Rec: Record Location)
    var
        LocationM: Record Location;
    begin
        LocationM.Reset();
        LocationM.SetRange("Global Dimension 2 Code", rec."Global Dimension 2 Code");
        If LocationM.FindFirst() then
            Rec."Region Code" := LocationM."Region Code"

    end;

    [EventSubscriber(ObjectType::Page, Page::"Purchase Credit Memo", 'OnafterValidateevent', 'Applies-to Doc. No.', false, False)]
    local procedure UpdateBrockerage(Var Rec: Record "Purchase Header")
    var
        PostedInvoice: record "Purch. Inv. Header";
    begin
        If Rec."Applies-to Doc. Type" = Rec."Applies-to Doc. Type"::Invoice then begin
            PostedInvoice.Reset();
            PostedInvoice.SetRange("No.", Rec."Applies-to Doc. No.");
            If PostedInvoice.FindFirst() then begin
                Rec.Validate("Brokerage Code", PostedInvoice."Brokerage Code");
                Rec.Validate("Brokerage Rate", PostedInvoice."Brokerage Rate");
            end else begin
                Rec.Validate("Brokerage Code", '')
            end

        end;

    end;

    [EventSubscriber(ObjectType::Table, DataBase::"Purchase Header", 'OnAfterAppliesToDocNoOnLookup', '', false, False)]
    local procedure UpdateBrockerageonafterlookup(var PurchaseHeader: Record "Purchase Header"; VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        PostedInvoice: record "Purch. Inv. Header";
    begin
        If PurchaseHeader."Applies-to Doc. Type" = PurchaseHeader."Applies-to Doc. Type"::Invoice then begin
            PostedInvoice.Reset();
            PostedInvoice.SetRange("No.", VendorLedgerEntry."Document No.");
            If PostedInvoice.FindFirst() then
                PurchaseHeader.Validate("Brokerage Code", PostedInvoice."Brokerage Code");
        end;
    end;

    [EventSubscriber(ObjectType::Table, 14, 'OnafterValidateevent', 'State Code', false, False)]
    local procedure RegionCodeValidate(Var Rec: Record Location)
    begin

        If Rec."Global Dimension 1 Code" in ['CBF'] then
            Rec.TestField(Rec."Region Code");
    end;


    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Location Code', false, false)]
    local procedure GSTNoCheck(var Rec: Record "Sales Header"; var xRec: Record "Sales Header")

    begin
        If (Rec."Customer GST Reg. No." <> '') and (Rec."Location GST Reg. No." <> '') then begin
            if rec."Customer GST Reg. No." = Rec."Location GST Reg. No." then
                Rec."Same GST" := True;
        end else
            Rec."Same GST" := False;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterValidateEvent', 'Sell-to Customer No.', false, false)]
    local procedure GSTNoCheckSell(var Rec: Record "Sales Header"; var xRec: Record "Sales Header")

    begin
        If (Rec."Customer GST Reg. No." <> '') and (Rec."Location GST Reg. No." <> '') then begin
            if rec."Customer GST Reg. No." = Rec."Location GST Reg. No." then
                Rec."Same GST" := True;
        end else
            Rec."Same GST" := False;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterValidateEvent', 'Location Code', false, false)]
    local procedure GSTNoCheckPurchase(var Rec: Record "Purchase Header"; var xRec: Record "Purchase Header")

    begin
        If (Rec."Vendor GST Reg. No." <> '') and (Rec."Location GST Reg. No." <> '') then begin
            if rec."Vendor GST Reg. No." = Rec."Location GST Reg. No." then
                Rec."Same GST" := True;
        end Else
            Rec."Same GST" := false;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnAfterValidateEvent', 'Appl.-to Item Entry', false, false)]
    local procedure Applytoentry(var Rec: Record "Transfer Line"; var xRec: Record "Transfer Line")
    var
        DocNo: Text;
        FromLocation: record Location;
        tolocation: Record Location;
        ItemLedgerEntry: Record "Item Ledger Entry";
        TransferReceiptLine: record "Transfer Receipt Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TRPrice: Decimal;
        PRPrice: Decimal;
    begin
        // Suman 080225//
        FromLocation.Get(Rec."Transfer-from Code");
        tolocation.Get(rec."Transfer-to Code");

        if FromLocation."State Code" <> tolocation."State Code" then begin
            if rec.Exempted = false Then Begin
                ItemLedgerEntry.RESET;
                ItemLedgerEntry.SETRANGE("Location Code", Rec."Transfer-from Code");
                ItemLedgerEntry.SETRANGE("Item No.", Rec."Item No.");
                ItemLedgerEntry.SetRange("Unit of Measure Code", Rec."Unit of Measure Code");
                ItemLedgerEntry.SetRange("Entry No.", Rec."Appl.-to Item Entry");
                ItemLedgerEntry.SETFILTER("Remaining Quantity", '<>%1', 0);
                //ItemLedgerEntry.SETFILTER("Document Type", '%1|%2', ItemLedgerEntry."Document Type"::"Purchase Receipt", ItemLedgerEntry."Document Type"::"Transfer Receipt");
                IF ItemLedgerEntry.FINDFIRST THEN
                    DocNo := ItemLedgerEntry."Document No.";
                //======================TransferReceiptLine=============
                CLEAR(TRPrice);
                CLEAR(PRPrice);
                TransferReceiptLine.RESET;
                TransferReceiptLine.SETRANGE("Document No.", DocNo);
                TransferReceiptLine.SETRANGE("Item No.", Rec."Item No.");
                IF TransferReceiptLine.FINDFIRST THEN
                    TRPrice := TransferReceiptLine."Unit Price";
                //===================PurchRcptLine==================
                PurchRcptLine.RESET;
                PurchRcptLine.SETRANGE("Document No.", DocNo);
                PurchRcptLine.SETRANGE("No.", Rec."Item No.");
                IF PurchRcptLine.FINDFIRST THEN
                    PRPrice := PurchRcptLine."Unit Cost";
                if (ItemLedgerEntry."Entry Type" = ItemLedgerEntry."Entry Type"::"Positive Adjmt.") and (ItemLedgerEntry."Entry Type" = ItemLedgerEntry."Entry Type"::Purchase) then begin
                    ItemLedgerEntry.CalcFields("Cost Amount (Actual)");
                    Rec.Validate("Transfer Price", (ItemLedgerEntry."Cost Amount (Actual)" / ItemLedgerEntry.Quantity));

                end;
                IF TRPrice <> 0 THEN
                    Rec.VALIDATE("Transfer Price", TRPrice)
                ELSE
                    IF PRPrice <> 0 THEN
                        Rec.VALIDATE("Transfer Price", PRPrice);
            End;
        end;

        // Suman 080225//
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnAfterValidateEvent', 'Quantity', false, false)]
    local procedure QtyValidate(var Rec: Record "Transfer Line"; var xRec: Record "Transfer Line")
    var
        SalesPrice: Record "Transfer Price";
        PostingDate: Date;
        Transferheader: Record "Transfer Header";
        ItemLedgerEntry: Record "Item Ledger Entry";
        DocNo: Code[20];
        TRPrice: Decimal;
        PRPrice: Decimal;
        TransferReceiptLine: Record "Transfer Receipt Line";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TransHeader: Record "Transfer Header";
        Item: Record Item;
        FromLocation: record Location;
        tolocation: Record Location;
        RecTransferLine: Record "Transfer Line";
        Items: Record Item;
        RecCompany: Record "Company Information";

    begin
        RecCompany.Get;
        if RecCompany.SFPLCompany = RecCompany.SFPLCompany::Sampoorna Then Begin
            Rec."GST Add on Inventory" := rec."GST Add on Inventory"::" Not Add";
            CLEAR(DocNo);
            FromLocation.Get(Rec."Transfer-from Code");
            tolocation.Get(rec."Transfer-to Code");

            Transferheader.Get(rec."Document No.");
            Item.Get(Rec."Item No.");
            SalesPrice.Reset();
            SalesPrice.SetRange("Item No", rec."Item No.");
            SalesPrice.SetRange("From Branch", FromLocation."Global Dimension 2 Code");
            SalesPrice.SetRange("To Branch", tolocation."Global Dimension 2 Code");
            //SalesPrice.SetRange("UOM", rec."Unit of Measure");
            SalesPrice.SetFilter("Start Date", '<=%1', Transferheader."Posting Date");
            SalesPrice.SetFilter("End Date", '%1|>=%2', 0D, Transferheader."Posting Date");
            if SalesPrice.FindFirst() then begin
                Rec.Validate(Rec."Transfer Price", (SalesPrice."Unit Price" * rec."Qty. per Unit of Measure"));
                Rec.MRP := True;
            end else begin
                // Item.Reset();
                // Item.SetRange("No.", Rec."Item No.");
                // Item.SetFilter("Item Category Code", 'POULTRY FD|FEED SUPPLEM|PREMIX|EGGS|CHICKS');
                // if Item.FindFirst() then begin
                If (FromLocation."Global Dimension 1 Code" = 'FEED') and (ToLocation."Global Dimension 1 Code" = 'CBF')
                 then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.SetFilter("Item Category Code", 'POULTRY FD|FEED SUPPLEM|PREMIX');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'POULTRY FD') or (Item."Item Category Code" = 'FEED SUPPLEM') or (Item."Item Category Code" = 'PREMIX')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;


                end;
                If (FromLocation."Global Dimension 1 Code" = 'FEED') and
                (ToLocation."Global Dimension 1 Code" = 'BREEDER') then Begin
                    // RecTransferLine.Reset();
                    // //RecTransferLine.SetRange(rec);
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Item No.", Rec."Item No.");
                    // RecTransferLine.SetFilter("Item Category Code", 'POULTRY FD|FEED SUPPLEM|PREMIX');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'POULTRY FD') or (Item."Item Category Code" = 'FEED SUPPLEM') or (Item."Item Category Code" = 'PREMIX')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;
                If (FromLocation."Global Dimension 1 Code" = 'FEED') and
        (ToLocation."Location Type" = tolocation."Location Type"::Store) then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.SetFilter("Item Category Code", 'POULTRY FD|FEED SUPPLEM');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'POULTRY FD') or (Item."Item Category Code" = 'FEED SUPPLEM')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;
                If (FromLocation."Global Dimension 1 Code" = 'BREEDER') and
                   (ToLocation."Global Dimension 1 Code" = 'HATCH') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.SetFilter("Item Category Code", 'Eggs');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'Eggs')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;

                end;

                If (FromLocation."Global Dimension 1 Code" = 'HATCH') and
                   (ToLocation."Global Dimension 1 Code" = 'CBF') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.Setfilter("Item Category Code", 'CHICKS');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.")
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'CHICKS')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;
                If (FromLocation.Code = 'SFPL0080') and
                   (ToLocation."Global Dimension 1 Code" = 'FEED') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.Setfilter("Item Category Code", 'PREMIX');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.")
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'PREMIX')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;

                end;
                If (FromLocation.Code = 'SFPL0080') and
                   (ToLocation."Global Dimension 1 Code" = 'CBF') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.Setfilter("Item Category Code", 'PREMIX');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.")
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'PREMIX')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;
                If (FromLocation."Global Dimension 1 Code" = 'FEED') and
                   (ToLocation."Global Dimension 1 Code" = 'CATTLE') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.Setfilter("Item Category Code", 'CATTLE FD');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.")
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'CATTLE FD')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;
                If (FromLocation.Code = 'SFPL0054') and
                   (ToLocation."Global Dimension 1 Code" = 'FEED') then Begin
                    // RecTransferLine.Reset();
                    // RecTransferLine.SetRange("Document No.", rec."Document No.");
                    // RecTransferLine.SetRange("Line No.", rec."Line No.");
                    // RecTransferLine.Setfilter("Item Category Code", 'CATTLE FD|POULTRY FD');
                    // RecTransferLine.SetRange(MRP, false);
                    // If RecTransferLine.FindFirst() then
                    //     Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.")
                    if Rec."Item No." <> '' then
                        if ((Item."Item Category Code" = 'CATTLE FD') or (Item."Item Category Code" = 'POULTRY FD')) then begin
                            if (Rec.MRP = false) then
                                Error('MRP is missing in Line No. %1 and Item No. %2, Please contact to Sale Accounts Team', RecTransferLine."Line No.", RecTransferLine."Item No.");
                        end;
                end;


                //end else begin

                ItemLedgerEntry.RESET;
                ItemLedgerEntry.SETRANGE("Location Code", Rec."Transfer-from Code");
                ItemLedgerEntry.SETRANGE("Item No.", Rec."Item No.");
                ItemLedgerEntry.SetRange("Unit of Measure Code", Rec."Unit of Measure Code");
                ItemLedgerEntry.SETFILTER("Remaining Quantity", '<>%1', 0);
                ItemLedgerEntry.SETFILTER("Document Type", '%1|%2', ItemLedgerEntry."Document Type"::"Purchase Receipt", ItemLedgerEntry."Document Type"::"Transfer Receipt");
                IF ItemLedgerEntry.FINDFIRST THEN
                    DocNo := ItemLedgerEntry."Document No.";
                //======================TransferReceiptLine=============
                CLEAR(TRPrice);
                CLEAR(PRPrice);
                TransferReceiptLine.RESET;
                TransferReceiptLine.SETRANGE("Document No.", DocNo);
                TransferReceiptLine.SETRANGE("Item No.", Rec."Item No.");
                IF TransferReceiptLine.FINDFIRST THEN
                    TRPrice := TransferReceiptLine."Unit Price";
                //===================PurchRcptLine==================
                PurchRcptLine.RESET;
                PurchRcptLine.SETRANGE("Document No.", DocNo);
                PurchRcptLine.SETRANGE("No.", Rec."Item No.");
                IF PurchRcptLine.FINDFIRST THEN
                    PRPrice := PurchRcptLine."Unit Cost";


                //GK

                IF TRPrice <> 0 THEN
                    Rec.VALIDATE("Transfer Price", TRPrice)
                ELSE
                    IF PRPrice <> 0 THEN
                        Rec.VALIDATE("Transfer Price", PRPrice)
                    ELSE
                        Rec.VALIDATE("Transfer Price", Item."Unit Cost" * Rec."Qty. per Unit of Measure");
                Rec.MRP := false;
            end;
        end;
    end;



    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterValidateEvent', 'Buy-from Vendor No.', false, false)]
    local procedure GSTNoCheckPurchaseSell(var Rec: Record "Purchase Header"; var xRec: Record "Purchase Header")

    begin
        If (Rec."Vendor GST Reg. No." <> '') and (Rec."Location GST Reg. No." <> '') then begin
            if rec."Vendor GST Reg. No." = Rec."Location GST Reg. No." then
                Rec."Same GST" := True;
        end Else
            Rec."Same GST" := false;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnAfterValidateEvent', 'Transfer-from Code', false, false)]
    local procedure TranferFromCode(var Rec: Record "Transfer Header"; var xRec: Record "Transfer Header")
    var
        TRanferLine: Record "Transfer Line";

    begin

        If Rec."Transfer-from Code" <> xRec."Transfer-from Code" Then begin
            TRanferLine.Reset();
            TRanferLine.SetRange("Document No.", rec."No.");
            if Not TRanferLine.IsEmpty() then
                Error('Please delete the Transfer Line First, Then Change the Transfer From Code')

        end;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeValidateTransferToCode', '', false, false)]
    local procedure OnBeforeValidateTransferToCode(var TransferHeader: Record "Transfer Header"; var xTransferHeader: Record "Transfer Header"; var IsHandled: Boolean; var HideValidationDialog: Boolean)
    begin
        HideValidationDialog := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnBeforeValidateTransferFromCode', '', false, false)]
    local procedure OnBeforeValidateTransferFromCode(var TransferHeader: Record "Transfer Header"; var xTransferHeader: Record "Transfer Header"; var IsHandled: Boolean; var HideValidationDialog: Boolean)
    begin
        HideValidationDialog := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnAfterValidateEvent', 'Transfer-to Code', false, false)]
    local procedure TranferToCode(var Rec: Record "Transfer Header"; var xRec: Record "Transfer Header")
    var
        TRanferLine: Record "Transfer Line";

    begin
        Rec.Validate("In-Transit Code", 'IN-TRANSIT');
        If Rec."Transfer-to Code" <> xRec."Transfer-to Code" Then begin
            TRanferLine.Reset();
            TRanferLine.SetRange("Document No.", rec."No.");
            if Not TRanferLine.IsEmpty() then
                Error('Please delete the Transfer Line First, Then Change the Transfer To Code')

        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Transfer Shipment", 'OnBeforeOnRun', '', false, false)]
    local procedure OnBeforeOnRunInterstateUndo(var TransferShipmentLine: Record "Transfer Shipment Line"; var IsHandled: Boolean; var HideDialog: Boolean)
    var
        fromLoc: Record Location;
        ToLOC: Record Location;
    begin
        fromLoc.Get(TransferShipmentLine."Transfer-from Code");
        ToLOC.Get(TransferShipmentLine."Transfer-to Code");

        if fromLoc."State Code" <> ToLOC."State Code" then
            Error('You Can not undo Interstate Transaction');


    end;

    [EventSubscriber(ObjectType::Codeunit, 80, 'OnAfterPostSalesDoc', '', false, false)]
    local procedure OnAfterPostSalesDoc(var SalesHeader: Record 36; var GenJnlPostLine: Codeunit 12; SalesShptHdrNo: Code[20]; RetRcpHdrNo: Code[20]; SalesInvHdrNo: Code[20]; SalesCrMemoHdrNo: Code[20])
    var
        SalesInvoiceHeader: Record 112;
        cuSalesPost: Codeunit 80;
        //Cod50031: Codeunit SalesPostExt;
        // GSTManagement: Codeunit 16401;
        SMSfunctions: Codeunit 50018;
        DuplicateBranch: Code[10];
        SalesCrMemoHeader: Record 114;
        SalesCrMemoHeader1: Record 114;
        Customer: Record 18;
        ReportPath: Text;
        SFPLSMSBody: Text;
        STARSMSBody: Text;
        CustAmt: Decimal;
        CustBalance: Decimal;
        CustName: Text;
        Customer18: Record 18;
        "InvoiceNo.": Text;
        SalesInvoiceHeader1: Record 112;
        Outstr: OutStream;
        Instr: InStream;
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        Email: Codeunit Email;
        EmailBody: Text;
        CU50017: Codeunit 50024;
        CU50018: Codeunit EInvoicing;
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        TCSEntryRec: Record "TCS Entry";
        TotalGSTAMt: Decimal;
        TCSAMt: Decimal;
        Companyinfo: Record "Company Information";
        SalesandRec: Record "Sales & Receivables Setup";
        SalesInvoiceHeaderReport: Record "Sales Invoice Header";
        FilePath: Text;
        FileManagment: Codeunit "File Management";
        WhatsApp: Codeunit "WhatsApp Function";
        PhoneNo: Text;
        Cust: Record Customer;
        FileName: text;
        ReportSalesInvoice: Report "Sales Invoice New-GST";
        ReportSalesInvoiceJob: Report "Sales Invoice JOB New-GST";
        APIFunction: Codeunit "API Functions";
        SMSDetail: Codeunit "SMS Details";
        Salesperson: Record "Salesperson/Purchaser";
    begin
        // Message('%1', SalesInvHdrNo);
        Companyinfo.Get;
        SalesandRec.Get;

        IF SalesInvHdrNo <> '' THEN BEGIN
            SalesInvoiceHeader.RESET;
            SalesInvoiceHeader.SETRANGE(SalesInvoiceHeader."No.", SalesInvHdrNo);
            IF SalesInvoiceHeader.FINDFIRST THEN BEGIN
                APIFunction.GeneratePaymentQRCOdeforInvoice(SalesInvoiceHeader."No.");
                //CU50017.GetAccessToken(SalesInvoiceHeader."No.");
            END;
        END;
        IF SalesInvHdrNo <> '' THEN BEGIN
            SalesInvoiceHeader.RESET;
            SalesInvoiceHeader.SETRANGE(SalesInvoiceHeader."Posting Date", 20211001D, TODAY);
            SalesInvoiceHeader.SETRANGE(SalesInvoiceHeader."Pay QR Created", FALSE);
            IF SalesInvoiceHeader.FINDSET THEN
                REPEAT
                    APIFunction.GeneratePaymentQRCOdeforInvoice(SalesInvoiceHeader."No.");
                //CU50017.GetAccessToken(SalesInvoiceHeader."No.");
                //S.M         GenerateVertualPayQR(SalesInvoiceHeader."No.");
                UNTIL SalesInvoiceHeader.NEXT = 0;
        END;

        //gk
        IF SalesInvHdrNo <> '' THEN BEGIN
            CLEAR(CustBalance);
            CLEAR(CustAmt);
            CLEAR(CustName);
            SalesInvoiceHeader.RESET;
            SalesInvoiceHeader.SETRANGE(SalesInvoiceHeader."No.", SalesInvHdrNo);
            //SalesInvoiceHeader.SETFILTER(SalesInvoiceHeader."Shortcut Dimension 1 Code", '<>%1', 'CATTLE');
            IF SalesInvoiceHeader.FINDFIRST THEN BEGIN
                Clear(TotalGSTAMt);
                Clear(TCSAMt);
                DetailedGSTLedgerEntry.RESET;
                // DetailedGSTLedgerEntry.SETRANGE(DetailedGSTLedgerEntry."Document Type", DetailedGSTLedgerEntry."Document Type"::Invoice);
                //DetailedGSTLedgerEntry.SETRANGE(DetailedGSTLedgerEntry."Transaction Type", DetailedGSTLedgerEntry."Transaction Type"::Sales);
                DetailedGSTLedgerEntry.SETRANGE(DetailedGSTLedgerEntry."Document No.", SalesInvoiceHeader."No.");
                IF DetailedGSTLedgerEntry.FINDSET THEN
                    REPEAT
                        TotalGSTAMt += ABS(DetailedGSTLedgerEntry."GST Amount");
                    until DetailedGSTLedgerEntry.next = 0;

                TCSEntryRec.Reset();
                TCSEntryRec.SetRange("Document No.", SalesInvoiceHeader."No.");
                if TCSEntryRec.FindFirst() then
                    repeat
                        TCSAMt += TCSEntryRec."TCS Amount";
                    until TCSEntryRec.Next() = 0;

                SalesInvoiceHeader.CALCFIELDS(Amount);
                CustAmt := SalesInvoiceHeader.Amount + TotalGSTAMt + TCSAMt;
                "InvoiceNo." := SalesInvoiceHeader."No.";
                Customer.RESET;
                Customer.SETRANGE("No.", SalesInvoiceHeader."Sell-to Customer No.");
                IF Customer.FINDFIRST THEN BEGIN
                    Customer.CALCFIELDS(Balance);
                    CustBalance := Customer.Balance;
                    CustName := COPYSTR(Customer.Name, 1, 30);
                    Customer18.RESET;
                    Customer18.SETRANGE("No.", Customer."No.");
                    IF Customer18.FINDFIRST THEN
                        REPEAT
                            // CustName := ReplaceString(CustName, '&', '%26');
                            // CustName := ReplaceString(CustName, '.', '%2E');
                            // CustName := ReplaceString(CustName, '-', '%2E');
                            // "InvoiceNo." := ReplaceString("InvoiceNo.", '/', '%2F');
                            if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then Begin
                                SFPLSMSBody := 'Dear' + ' ' +
                               FORMAT(CustName) + ',' + ' ' + 'Invoice No.' + ' ' + FORMAT("InvoiceNo.") + ' ' + 'dated ' + FORMAT(SalesInvoiceHeader."Posting Date") + ' ' + 'has been generated for Rs.' + ' ' + FORMAT(CustAmt) + ' ' + 'and outstanding as on date is Rs. ' +
                               FORMAT(CustBalance) + ',' + ' Sampoorna Feeds Pvt Ltd.';
                            End;
                            if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] Then Begin
                                STARSMSBody := 'Dear' + ' ' +
                                          FORMAT(CustName) + ',' + ' ' + 'Invoice No.' + ' ' + FORMAT("InvoiceNo.") + ' ' + 'dated ' + FORMAT(SalesInvoiceHeader."Posting Date") + ' ' + 'has been generated for Rs.' + ' ' + FORMAT(CustAmt) + ' ' + 'and outstanding as on date is Rs. ' +
                                           FORMAT(CustBalance) + ',' + ' STAR FOODS.';
                            end;
                        UNTIL Customer18.NEXT = 0;
                END;
            END;
        END;

        IF Customer.GET(Customer."No.") THEN BEGIN
            IF Customer."Outstanding SMS" THEN begin
                if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::"Star Foods"] Then
                    SMSDetail.APISMSMultipleNo(Customer."Phone No.", Customer."Mobile Phone No.", Customer."WhatsApp Mobile No.", Customer."Alternate Phone No. 1", Customer."Alternate Phone No. 2", '', '', STARSMSBody, '', Customer."No.", '1307173416324318136');// Airtel
                                                                                                                                                                                                                                                                      //WhatsApp.SendSMS(Customer."Phone No.", STARSMSBody, '', Customer."No.", '1307173416324318136');
                if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then
                    SMSDetail.APISMSMultipleNo(Customer."Phone No.", Customer."Mobile Phone No.", Customer."WhatsApp Mobile No.", Customer."Alternate Phone No. 1", Customer."Alternate Phone No. 2", '', '', SFPLSMSBody, '', Customer."No.", '1307165932637364146');// Airtel
                                                                                                                                                                                                                                                                      //WhatsApp.SendSMS(Customer."Phone No.", SFPLSMSBody, '', Customer."No.", '1307165932637364146');
                                                                                                                                                                                                                                                                      //SendSMSByURL(SMSBody);

            end;
        END;

        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then
            IF SalesInvHdrNo <> '' THEN BEGIN
                SalesInvoiceHeaderReport.RESET;
                SalesInvoiceHeaderReport.SETRANGE(SalesInvoiceHeaderReport."No.", SalesInvHdrNo);
                IF SalesInvoiceHeaderReport.FINDFIRST THEN BEGIN
                    FileName := 'D:\Whatsapp\' + 'Invoice' + SalesInvoiceHeaderReport."No." + '.pdf';
                    //if (SalesInvoiceHeaderReport."Shiiping From" <> 'SFPL0093') and (SalesInvoiceHeaderReport."Shiiping From" <> 'SFPL0137') and (SalesInvoiceHeaderReport."Shortcut Dimension 1 Code" <> 'CATTLE') then begin
                    Clear(ReportSalesInvoice);
                    ReportSalesInvoice.SetTableView(SalesInvoiceHeaderReport);
                    ReportSalesInvoice.SaveAsPdf(FileName);
                    // end else begin
                    //     Clear(ReportSalesInvoiceJob);
                    //     ReportSalesInvoiceJob.SetTableView(SalesInvoiceHeaderReport);
                    //     ReportSalesInvoiceJob.SaveAsPdf(FileName);
                    // end;
                    If Customer."WhatsApp SMS" Then
                        InvoiceSendonWhatsapp(SalesInvoiceHeaderReport."No.", SalesInvoiceHeaderReport."Bill-to Customer No.");

                    IF Customer."E-Mail" <> '' THEN BEGIN
                        Clear(SMTPMail);
                        Clear(Email);
                        EmailBody := ('Dear Sir' + ',');
                        EmailBody += ('<br><br>');
                        EmailBody += ('Please find enclosed herewith your Invoice as per above mentioned subject for your kind perusal. If you found any discrepancy kindly let us know within 7 days after receiving the mail.');
                        EmailBody += ('<br><br>');
                        EmailBody += ('For any further information, please feel free to contact our dedicated executive.');
                        EmailBody += ('<br><br>');
                        SMTPMail.Create(Customer."E-Mail", 'Invoice' + ' ' + '(' + SalesInvoiceHeader."No." + ')', EmailBody, true);
                        //   SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, Customer."E-Mail");
                        if SalesInvoiceHeaderReport."Salesperson Code" <> '' Then begin
                            Salesperson.GET(SalesInvoiceHeaderReport."Salesperson Code");
                            if Salesperson.Code = 'ARVIND' then
                                if Salesperson."E-Mail" <> '' Then
                                    SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, Salesperson."E-Mail");
                        end;
                        FileManagment.BLOBImportFromServerFile(TempBlob, FileName);
                        TempBlob.CreateInStream(Instr);
                        SMTPMail.AddAttachment(SalesInvoiceHeaderReport."No." + '.pdf', 'PDF', Instr);
                        SMTPMail.AppendToBody('With best regards!' + ',');
                        SMTPMail.AppendToBody('<BR>');
                        SMTPMail.AppendToBody('Sampoorna Team');
                        SMTPMail.AppendToBody('<BR><BR>');
                        SMTPMail.AppendToBody('Note : This is computer generated mail, please do-not reply on this.<BR><BR>');
                        Email.Send(SMTPMail, Enum::"Email Scenario"::Default);
                    end;
                END;
            END;


        //Mail Code Block As request by user
        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then
            IF SalesCrMemoHdrNo <> '' THEN BEGIN
                SalesCrMemoHeader.RESET;
                SalesCrMemoHeader.SETRANGE(SalesCrMemoHeader."No.", SalesCrMemoHdrNo);
                IF SalesCrMemoHeader.FINDSET THEN BEGIN
                    REPEAT
                        if SalesCrMemoHeader."Salesperson Code" <> '' Then
                            Salesperson.GET(SalesCrMemoHeader."Salesperson Code");
                        //         SMTPMailSetup.GET;
                        Customer.RESET;
                        Customer.SETRANGE("No.", SalesCrMemoHeader."Bill-to Customer No.");
                        IF Customer.FINDFIRST THEN BEGIN
                            SMTPMail.Create(Customer."E-Mail", 'Credit Note of' + ' ' + '(' + Customer.Name + '_' + SalesCrMemoHeader."No." + ')', '', true);
                            SMTPMail.SetBodyHTMLFormatted(true);
                            SMTPMail.AppendToBody('Dear Sir,');
                            SMTPMail.AppendToBody('<BR><BR>');
                            SMTPMail.AppendToBody('Please find enclosed herewith your Credit Note as per above mentioned subject for your kind perusal. If you found any discrepancy kindly let us know within 7 days after receiving the mail.');
                            SMTPMail.AppendToBody('<BR><BR>');
                            SMTPMail.AppendToBody('For any further information, please feel free to contact our dedicated executive.');
                            SMTPMail.AppendToBody('<BR><BR>');

                            //SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, Salesperson."E-Mail");
                            //SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Bcc, 'sumandev@sampoornafeeds.in');
                            FilePath := 'D:\Whatsapp\' + 'CreditNote' + SalesCrMemoHdrNo + '.pdf';
                            RecRef.GetTable(SalesCrMemoHeader);
                            TempBlob.CreateOutStream(Outstr);
                            Report.SaveAs(Report::"Credit Note", '', ReportFormat::Pdf, Outstr, RecRef);
                            //                   Report.SaveAs(Report::"Stock DeliveryReport", '', ReportFormat::Pdf, Outstr, RecRef);
                            TempBlob.CreateInStream(Instr);
                            SMTPMail.AddAttachment(SalesCrMemoHeader."No." + '.pdf', 'PDF', Instr);
                            FileManagment.BLOBExportToServerFile(TempBlob, FilePath);
                            //SMTPMail.AddAttachment(ReportPath, 'Credit Note_' + DELCHR(SalesCrMemoHeader1."No.", '=', '/') + '.pdf');
                            SMTPMail.AppendToBody('With best regards!' + ',');
                            SMTPMail.AppendToBody('<BR>');
                            SMTPMail.AppendToBody('Sampoorna Team');
                            SMTPMail.AppendToBody('<BR><BR>');
                            SMTPMail.AppendToBody('Note : This is computer generated mail, please do-not reply on this.<BR><BR>');
                            Email.Send(SMTPMail, Enum::"Email Scenario"::Default);

                            if Customer."WhatsApp Mobile No." <> '' then
                                PhoneNo := Customer."WhatsApp Mobile No."
                            else
                                PhoneNo := Customer."Phone No.";
                            If Customer."WhatsApp SMS" Then
                                //WhatsApp.WhatsAppAPI(WhatsApp.WhatsAppInvoice(PhoneNo, Customer.Name, SalesCrMemoHeader."Posting Date", SalesCrMemoHeader."No.", 'https://sfplwhatsapp.sampoornafeeds.in/' + 'CreditNote' + SalesCrMemoHdrNo + '.pdf', SalesCrMemoHdrNo, 'creditnotenew'));
                                WhatsApp.AirtelWhatssAppAPI(WhatsApp.WhatsAppInvoice(PhoneNo, Customer.Name, SalesCrMemoHeader."Posting Date", SalesCrMemoHeader."No.", 'https://sfplwhatsapp.sampoornafeeds.in/' + 'CreditNote' + SalesCrMemoHdrNo + '.pdf', SalesCrMemoHdrNo, '01kgrs05pm09mnfbg4drzyjzrs'));

                        END;

                    UNTIL SalesCrMemoHeader.NEXT = 0;

                END;
            END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterReleaseSalesDoc', '', false, false)]
    procedure UpdateOrderQtyinApprovalEntry(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean)
    var
        ApprovalEntry: Record "Approval Entry";
        DeleteApprovalEntry: Record "Approval Entry";
        SalesLine: Record "Sales Line";
        APIFunction: Codeunit "API Functions";

    begin
        //If not PreviewMode then
        SalesLine.Reset();
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            SalesLine.CalcSums(Quantity);
        ApprovalEntry.Reset();
        ApprovalEntry.SetRange("Document Type", SalesHeader."Document Type"::Order);
        ApprovalEntry.SetRange("Document No.", SalesHeader."No.");
        if ApprovalEntry.FindSet() then
            repeat
                ApprovalEntry."Order Qty" := SalesLine.Quantity;
                ApprovalEntry.Modify();

            Until ApprovalEntry.Next() = 0;

        ApprovalEntry.RESET;
        ApprovalEntry.SETRANGE(ApprovalEntry."Document No.", SalesHeader."No.");
        ApprovalEntry.SETRANGE(ApprovalEntry."Sequence No.", 1);
        ApprovalEntry.SETRANGE(ApprovalEntry.Status, ApprovalEntry.Status::Approved);
        IF ApprovalEntry.FINDFIRST THEN BEGIN
            DeleteApprovalEntry.RESET;
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry."Document No.", SalesHeader."No.");
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry."Sequence No.", 1);
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry.Status, DeleteApprovalEntry.Status::Open);
            IF DeleteApprovalEntry.FINDSET THEN
                DeleteApprovalEntry.DELETEALL;

        end;

        // If SalesHeader."Created From Web" then
        //     APIFunction.UpdateOrderStatus(SalesHeader."No.", SalesHeader.Status);



    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterManualReleaseSalesDoc', '', false, false)]
    procedure Onaftermanualreleasesalesdocu(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean)
    var
        APIFunction: Codeunit "API Functions";
    Begin
        If SalesHeader."Created From Web" then
            APIFunction.UpdateOrderStatus(SalesHeader."No.", SalesHeader.Status);
    End;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Sales Document", 'OnAfterManualReOpenSalesDoc', '', false, false)]
    procedure PerformManualReopen(var SalesHeader: Record "Sales Header"; PreviewMode: Boolean)
    var
        APIFunction: Codeunit "API Functions";
    Begin
        If SalesHeader."Created From Web" then
            APIFunction.UpdateOrderStatus(SalesHeader."No.", SalesHeader.Status);
    End;





    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Release Purchase Document", 'OnAfterReleasePurchaseDoc', '', false, false)]
    procedure SendPOtoVendor(var PurchaseHeader: Record "Purchase Header"; PreviewMode: Boolean)
    var
        Vendor: Record Vendor;
        EmailBody: Text;
        SMTPMail: Codeunit "Email Message";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        PO1: Report "Purchase Order1";
        PurchHdr: Record "Purchase Header";
        PurcLine: Record "Purchase Line";
        Rep50002: Report 50002;
        recUser: Record User;
        recPurchaser: Record "Salesperson/Purchaser";
        ArchiveManagement: Codeunit ArchiveManagement;
        CompanyInfo: Record "Company Information";
    begin
        CompanyInfo.Get;


        if Not PreviewMode then
            if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna Then
                if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Order then
                    if not PurchHdr."PO Sent" then begin
                        Vendor.Reset();
                        Vendor.SetRange("No.", PurchaseHeader."Buy-from Vendor No.");
                        Vendor.Setfilter("E-Mail", '<>%1', '');
                        IF Vendor.FINDFIRST THEN BEGIN
                            Clear(SMTPMail);
                            Clear(Email);
                            recUser.get(UserSecurityId());
                            if PurchaseHeader."Purchaser Code" <> '' Then
                                recPurchaser.Get(PurchaseHeader."Purchaser Code");
                            EmailBody := ('To');
                            EmailBody += ('<br>');
                            EmailBody += (PurchaseHeader."Buy-from Vendor Name");
                            EmailBody += ('<br>');
                            EmailBody += (PurchaseHeader."Buy-from Vendor No.");
                            EmailBody += ('<br>');
                            EmailBody += (PurchaseHeader."Buy-from Address" + '' + PurchaseHeader."Buy-from Address 2");
                            EmailBody += ('<br>');
                            EmailBody += (PurchaseHeader."Pay-to City");
                            EmailBody += ('<br>');
                            EmailBody += (PurchaseHeader.State + '-' + PurchaseHeader."Buy-from Post Code");
                            EmailBody += ('<br><br>');
                            EmailBody += ('Dear Sir/Madam');
                            EmailBody += ('<br><br>');
                            EmailBody += ('As discussed telephonically, we have raised the attached Purchase order(PO) on your name.');
                            EmailBody += ('<br><br>');

                            PurcLine.Reset();
                            PurcLine.SetRange("Document No.", PurchaseHeader."No.");
                            PurcLine.SetFilter("Item Category Code", '%1', 'RM');
                            if PurcLine.FindFirst() Then begin
                                EmailBody += ('The PO will be valid up to' + ' ' + Format(PurchaseHeader."PO Expiration Date") + ' ' + 'from' + ' ' + Format(PurchaseHeader."Order Date") + ' ' + '(inclusive) with 5% tolerance for quantity variation from PO quantity, subject to specifications mentioned in the PO.');
                                EmailBody += ('<br><br>');
                                EmailBody += ('Kindly ensure loading the same by the' + ' ' + Format(PurchaseHeader."PO Expiration Date") + ' ' + 'to reach latest by' + ' ' + Format(PurchaseHeader."PO Expiration Date"));
                                EmailBody += ('<br><br>');
                                EmailBody += ('The acceptance of the goods supplied is subject to meeting quality specifications mentioned in the PO, with or without rebate as the case may be.');
                                EmailBody += ('<br><br>');
                                EmailBody += ('Kindly acknowledge receipt and supply accordingly.');
                            end else
                                //EmailBody += ('The PO will be valid up to' + ' ' + Format(PurchaseHeader."PO Expiration Date") + ' ' + 'from' + ' ' + Format(PurchaseHeader."Order Date"));


                                EmailBody += ('Kindly acknowledge email and update us the delivery accordingly.');
                            EmailBody += ('<br><br><br>');
                            SMTPMail.Create(Vendor."E-Mail", 'Purchase Order' + ' ' + '(' + PurchaseHeader."No." + ')', EmailBody, true);
                            SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, recUser."Contact Email");
                            SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, recPurchaser."E-Mail");
                            Clear(Outstr);
                            Clear(RecRef);
                            Clear(PO1);
                            PurchHdr.Reset();
                            PurchHdr.SetRange("Document Type", PurchaseHeader."Document Type");
                            PurchHdr.SetRange("No.", PurchaseHeader."No.");
                            if PurchHdr.FindFirst() then begin
                                RecRef.GetTable(PurchHdr);
                                TempBlob.CreateOutStream(Outstr);
                                Rep50002.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
                                // Report.SaveAs(50002, '', ReportFormat::Pdf, Outstr, RecRef);
                                //PO1.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
                                TempBlob.CreateInStream(Instr);
                                SMTPMail.AddAttachment(PurchaseHeader."No." + '.pdf', 'PDF', Instr);
                            end;
                            SMTPMail.AppendToBody('Thanking you' + ',');
                            SMTPMail.AppendToBody('<BR><BR>');
                            SMTPMail.AppendToBody('For Sampoorna Feeds Pvt Ltd');
                            SMTPMail.AppendToBody('<BR>');
                            SMTPMail.AppendToBody(PurchaseHeader."Ship-to Address" + '' + PurchaseHeader."Ship-to Address 2");
                            SMTPMail.AppendToBody('<BR>');
                            SMTPMail.AppendToBody(PurchaseHeader."Ship-to City" + ' ' + PurchaseHeader."Location State Code");
                            SMTPMail.AppendToBody('<BR>');
                            SMTPMail.AppendToBody(PurchaseHeader."Ship-to Country/Region Code" + '-' + PurchaseHeader."Ship-to Post Code");
                            SMTPMail.AppendToBody('<BR><BR>');
                            SMTPMail.AppendToBody('Note : This is computer generated mail, please do-not reply on this.<BR><BR>');
                            Email.Send(SMTPMail, Enum::"Email Scenario"::Default);
                            PurchaseHeader."PO Sent" := True;
                            ArchiveManagement.ArchivePurchDocument(PurchaseHeader);
                            PurchaseHeader.Modify();
                        End;


                    END;

    end;

    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnAfterValidateEvent', 'Amount', false, false)]
    local procedure OnBeforeActionEventPost(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        //if not GuiAllowed then begin

        if Rec."Source Code" = 'CASHPYMTV' Then begin
            If Rec."Line No." <> 0 Then begin
                Rec.TestField("Document Type");
                if ABS(Rec.Amount) > 10000 then
                    Error(Text001, '10,000');
            end;
        end;
        if Rec."Source Code" = 'CASHRCPTV' Then begin
            If Rec."Line No." <> 0 Then begin
                Rec.TestField("Document Type");
                If Rec.Amount <> 0 Then
                    if ABS(Rec.Amount) > 200000 then
                        Error(Text001, '2,00,000');
            end;
        end;

        //Message('%1', Rec.Amount);
        if Rec."Source Code" = 'CASHPYMTV' then begin

            GenJournalLine.Reset();
            GenJournalLine.SetRange(GenJournalLine."Journal Template Name", Rec."Journal Template Name");
            GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", Rec."Journal Batch Name");
            GenJournalLine.SetRange("Posting Date", Rec."Posting Date");
            GenJournalLine.SetRange(GenJournalLine."Account No.", Rec."Account No.");
            //GenJournalLine.SetRange(GenJournalLine."Document Type", GenJournalLine."Document Type"::Payment);
            GenJournalLine.SetFilter(GenJournalLine."Account Type", '%1|%2', GenJournalLine."Account Type"::Customer, GenJournalLine."Account Type"::Vendor);
            if GenJournalLine.FindSet() then
                repeat
                    LimitAmt := 0;
                    if (GenJournalLine."Document Type" = GenJournalLine."Document Type") and (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer) OR (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor) then begin
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor then begin
                            VLE.Reset();
                            VLE.SetRange("Source Code", 'CASHPYMTV');
                            VLE.SetRange(VLE."Document Type", VLE."Document Type"::Payment);
                            VLE.SetRange(VLE."Vendor No.", GenJournalLine."Account No.");
                            VLE.SetRange(VLE."Posting Date", GenJournalLine."Posting Date");
                            if VLE.FindSet() then begin
                                repeat
                                    VLE.CalcFields(Amount);
                                    LimitAmt += ABS(VLE.Amount);
                                until VLE.Next() = 0;
                            end;
                        end;
                        IF (ABS(Rec.Amount) + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 10000 then
                            Error(Text001, '10,000');
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer then begin
                            CLE.Reset();
                            CLE.SetRange("Source Code", 'CASHPYMTV');
                            CLE.SetRange(CLE."Document Type", VLE."Document Type"::Payment);
                            CLE.SetRange(CLE."Customer No.", GenJournalLine."Account No.");
                            CLE.SetRange(CLE."Posting Date", GenJournalLine."Posting Date");
                            if CLE.FindSet() then begin
                                repeat
                                    CLE.CalcFields(Amount);
                                    LimitAmt += ABS(CLE.Amount);
                                until CLE.Next() = 0;
                            end;
                        end;


                        IF (Rec.Amount + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 10000 then
                            Error(Text001, '10,000');
                    end;
                until GenJournalLine.Next() = 0;
        end;

        if Rec."Source Code" = 'CASHRCPTV' then begin

            GenJournalLine.Reset();
            GenJournalLine.SetRange(GenJournalLine."Journal Template Name", Rec."Journal Template Name");
            GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", Rec."Journal Batch Name");
            GenJournalLine.SetRange("Posting Date", Rec."Posting Date");
            GenJournalLine.SetRange(GenJournalLine."Account No.", Rec."Account No.");
            //GenJournalLine.SetRange(GenJournalLine."Document Type", GenJournalLine."Document Type"::Payment);
            GenJournalLine.SetFilter(GenJournalLine."Account Type", '%1|%2', GenJournalLine."Account Type"::Customer, GenJournalLine."Account Type"::Vendor);
            if GenJournalLine.FindSet() then
                repeat
                    LimitAmt := 0;
                    if (GenJournalLine."Document Type" = GenJournalLine."Document Type") and (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer) OR (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor) then begin
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor then begin
                            VLE.Reset();
                            VLE.SetRange("Source Code", 'CASHRCPTV');
                            VLE.SetRange(VLE."Document Type", VLE."Document Type"::Payment);
                            VLE.SetRange(VLE."Vendor No.", GenJournalLine."Account No.");
                            VLE.SetRange(VLE."Posting Date", GenJournalLine."Posting Date");
                            if VLE.FindSet() then begin
                                repeat
                                    VLE.CalcFields(Amount);
                                    LimitAmt += ABS(VLE.Amount);
                                until VLE.Next() = 0;
                            end;
                        end;
                        IF (ABS(Rec.Amount) + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 200000 then
                            Error(Text001, '2,00,000');
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer then begin
                            CLE.Reset();
                            CLE.SetRange("Source Code", 'CASHRCPTV');
                            CLE.SetRange(CLE."Document Type", VLE."Document Type"::Payment);
                            CLE.SetRange(CLE."Customer No.", GenJournalLine."Account No.");
                            CLE.SetRange(CLE."Posting Date", GenJournalLine."Posting Date");
                            if CLE.FindSet() then begin
                                repeat
                                    CLE.CalcFields(Amount);
                                    LimitAmt += ABS(CLE.Amount);
                                until CLE.Next() = 0;
                            end;
                        end;


                        IF (Rec.Amount + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 200000 then
                            Error(Text001, '2,00,000');
                    end;
                until GenJournalLine.Next() = 0;
        end;
        //end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnAfterValidateEvent', 'Debit Amount', false, false)]
    local procedure ValidateGLDebitAmt(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        PaymentLimit(Rec);

    end;

    [EventSubscriber(ObjectType::Table, Database::"Gen. Journal Line", 'OnAfterValidateEvent', 'Debit Amount', false, false)]
    local procedure ValidateGLCreditAmt(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        PaymentLimit(Rec);

    end;

    local procedure GetTotalCashValue(Accountno: Code[20]; BatchName: Code[10]; TemName: Code[10]; Pdate: Date; LinNo: Integer): Decimal
    var
        GenJournalLine: Record "Gen. Journal Line";
        CashValue: Decimal;
    begin
        CashValue := 0;
        GenJournalLine.Reset();
        GenJournalLine.SetFilter(GenJournalLine."Line No.", '<>%1', LinNo);
        GenJournalLine.SetRange(GenJournalLine."Journal Template Name", TemName);
        GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", BatchName);
        GenJournalLine.SetRange(GenJournalLine."Document Type", GenJournalLine."Document Type"::Payment);
        GenJournalLine.SetFilter(GenJournalLine."Account Type", '%1|%2', GenJournalLine."Account Type"::Customer, GenJournalLine."Account Type"::Vendor);
        GenJournalLine.SetRange("Account No.", Accountno);
        GenJournalLine.SetRange("Posting Date", Pdate);
        if GenJournalLine.FindSet() then
            repeat
                CashValue += Abs(GenJournalLine.Amount);
            until GenJournalLine.Next() = 0;
        exit(CashValue);

    end;

    procedure PaymentLimit(var Rec: Record "Gen. Journal Line")
    var
        CLE: Record "Cust. Ledger Entry";
        VLE: Record "Vendor Ledger Entry";
        LimitAmt: Decimal;
        GenJournalLine: Record "Gen. Journal Line";
    begin
        //if not GuiAllowed then begin
        if Rec."Source Code" = 'CASHPYMTV' Then begin
            If Rec."Line No." <> 0 Then
                Rec.TestField("Document Type");
            if ABS(Rec.Amount) > 10000 then
                Error(Text001, '10,000');
        end;

        if Rec."Source Code" = 'CASHRCPTV' Then begin
            If Rec."Line No." <> 0 Then
                Rec.TestField("Document Type");
            If Rec.Amount <> 0 Then
                if ABS(Rec.Amount) > 200000 then
                    Error(Text001, '2,00,000');
        end;
        //Message('%1', Rec.Amount);
        if Rec."Source Code" = 'CASHPYMTV' then begin

            GenJournalLine.Reset();
            GenJournalLine.SetRange(GenJournalLine."Journal Template Name", Rec."Journal Template Name");
            GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", Rec."Journal Batch Name");
            GenJournalLine.SetRange("Posting Date", Rec."Posting Date");
            GenJournalLine.SetRange(GenJournalLine."Account No.", Rec."Account No.");
            //GenJournalLine.SetRange(GenJournalLine."Document Type", GenJournalLine."Document Type"::Payment);
            GenJournalLine.SetFilter(GenJournalLine."Account Type", '%1|%2', GenJournalLine."Account Type"::Customer, GenJournalLine."Account Type"::Vendor);
            if GenJournalLine.FindSet() then
                repeat
                    LimitAmt := 0;
                    if (GenJournalLine."Document Type" = GenJournalLine."Document Type") and (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer) OR (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor) then begin
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor then begin
                            VLE.Reset();
                            VLE.SetRange("Source Code", 'CASHPYMTV');
                            VLE.SetRange(VLE."Document Type", VLE."Document Type"::Payment);
                            VLE.SetRange(VLE."Vendor No.", GenJournalLine."Account No.");
                            VLE.SetRange(VLE."Posting Date", GenJournalLine."Posting Date");
                            if VLE.FindSet() then begin
                                repeat
                                    VLE.CalcFields(Amount);
                                    LimitAmt += ABS(VLE.Amount);
                                until VLE.Next() = 0;
                            end;
                        end;
                        IF (ABS(Rec.Amount) + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 10000 then
                            Error(Text001, '10,000');
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer then begin
                            CLE.Reset();
                            CLE.SetRange("Source Code", 'CASHPYMTV');
                            CLE.SetRange(CLE."Document Type", VLE."Document Type"::Payment);
                            CLE.SetRange(CLE."Customer No.", GenJournalLine."Account No.");
                            CLE.SetRange(CLE."Posting Date", GenJournalLine."Posting Date");
                            if CLE.FindSet() then begin
                                repeat
                                    CLE.CalcFields(Amount);
                                    LimitAmt += ABS(CLE.Amount);
                                until CLE.Next() = 0;
                            end;
                        end;
                        IF (Rec.Amount + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 10000 then
                            Error(Text001, '10,000');
                    end;
                until GenJournalLine.Next() = 0;
        end;

        if Rec."Source Code" = 'CASHPYMTV' then begin

            GenJournalLine.Reset();
            GenJournalLine.SetRange(GenJournalLine."Journal Template Name", Rec."Journal Template Name");
            GenJournalLine.SetRange(GenJournalLine."Journal Batch Name", Rec."Journal Batch Name");
            GenJournalLine.SetRange("Posting Date", Rec."Posting Date");
            GenJournalLine.SetRange(GenJournalLine."Account No.", Rec."Account No.");
            //GenJournalLine.SetRange(GenJournalLine."Document Type", GenJournalLine."Document Type"::Payment);
            GenJournalLine.SetFilter(GenJournalLine."Account Type", '%1|%2', GenJournalLine."Account Type"::Customer, GenJournalLine."Account Type"::Vendor);
            if GenJournalLine.FindSet() then
                repeat
                    LimitAmt := 0;
                    if (GenJournalLine."Document Type" = GenJournalLine."Document Type") and (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer) OR (GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor) then begin
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Vendor then begin
                            VLE.Reset();
                            VLE.SetRange("Source Code", 'CASHRCPTV');
                            VLE.SetRange(VLE."Document Type", VLE."Document Type"::Payment);
                            VLE.SetRange(VLE."Vendor No.", GenJournalLine."Account No.");
                            VLE.SetRange(VLE."Posting Date", GenJournalLine."Posting Date");
                            if VLE.FindSet() then begin
                                repeat
                                    VLE.CalcFields(Amount);
                                    LimitAmt += ABS(VLE.Amount);
                                until VLE.Next() = 0;
                            end;
                        end;
                        IF (ABS(Rec.Amount) + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 200000 then
                            Error(Text001, '2,00,000');
                        if GenJournalLine."Account Type" = GenJournalLine."Account Type"::Customer then begin
                            CLE.Reset();
                            CLE.SetRange("Source Code", 'CASHRCPTV');
                            CLE.SetRange(CLE."Document Type", VLE."Document Type"::Payment);
                            CLE.SetRange(CLE."Customer No.", GenJournalLine."Account No.");
                            CLE.SetRange(CLE."Posting Date", GenJournalLine."Posting Date");
                            if CLE.FindSet() then begin
                                repeat
                                    CLE.CalcFields(Amount);
                                    LimitAmt += ABS(CLE.Amount);
                                until CLE.Next() = 0;
                            end;
                        end;
                        IF (Rec.Amount + LimitAmt + GetTotalCashValue(Rec."Account No.", Rec."Journal Batch Name", Rec."Journal Template Name", GenJournalLine."Posting Date", Rec."Line No.")) > 200000 then
                            Error(Text001, '2,00,000');
                    end;
                until GenJournalLine.Next() = 0;
        end;
        //end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostItemChargePerOrder', '', false, false)]
    local procedure PostItemCharge(var PurchHeader: Record "Purchase Header";
    var PurchLine: Record "Purchase Line";
    var ItemJnlLine2: Record "Item Journal Line";
    var ItemChargePurchLine: Record "Purchase Line";
    var TempTrackingSpecificationChargeAssmt: Record "Tracking Specification" temporary;
    CommitIsSupressed: Boolean;
    var TempItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)" temporary;
    var IsHandled: Boolean)
    var
        PurcH: Record "Purchase Header";
        QtyToInvoice: Decimal;
        Currency: Record Currency;
        PreciseTotalChargeAmt: Decimal;
        CurrExchRate: Record "Currency Exchange Rate";
        RoundedPrevTotalChargeAmt: Decimal;
        TotalPurchLineLCY: Record "Purchase Line";
        TotalPurchLine: Record "Purchase Line";
        GLSetup: Record "General Ledger Setup";
        PurPost: Codeunit "Purch.-Post";
    begin

        TempItemChargeAssgntPurch."Amount to Handle" := TempItemChargeAssgntPurch."Amount to Assign";

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"GST Application Handler", 'OnBeforePostGSTWithNormalPaymentOffline', '', false, false)]
    local procedure SkipRCMEntryoffline(var GenJournalLine: Record "Gen. Journal Line"; var AmountToApply: Decimal; var IsHandled: Boolean)
    begin
        IsHandled := true;

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"GST Application Handler", 'OnBeforePostGSTWithNormalPaymentOnline', '', false, false)]
    local procedure SkipRCMEntryonline(var GenJournalLine: Record "Gen. Journal Line"; var AmountToApply: Decimal; var IsHandled: Boolean)
    begin
        IsHandled := true;

    end;

    [EventSubscriber(ObjectType::Table, DataBase::Customer, 'OnBeforeValidateEvent', 'Phone No.', false, false)]
    local procedure OnBeforevalidatePhoneNO(var Rec: Record Customer)
    var
        Cust: Record Customer;
    begin
        if Rec."Phone No." <> '' then
            If StrLen(Rec."Phone No.") <> 10 then
                Error('Phone No. Must be 10 Digit Only');

    end;

    [EventSubscriber(ObjectType::Table, DataBase::Customer, 'OnBeforeValidateEvent', 'WhatsApp Mobile No.', false, false)]
    local procedure OnBeforevalidateWhatsAppMobileNo(var Rec: Record Customer)
    var
        Cust: Record Customer;
    begin
        if Rec."WhatsApp Mobile No." <> '' then
            If StrLen(Rec."WhatsApp Mobile No.") <> 10 then
                Error('Phone No. Must be 10 Digit Only');


    end;


    procedure WelcomeEmailSMS(Type: Option Vendor,Customer; MasterCOde: Code[20])
    var
        Text001: Label 'Dear Sir/Madam;';
        Text002: Label 'Welcome to Sampoorna family';
        Text003: Label 'Your Business Account has been created and please refer to your business account no. %1 in future for any query.';
        Text004: Label 'Kindly feel free write to us at info@sampoornafeeds.com.';
        Vendor: Record Vendor;
        Customer: record Customer;
        SMTPemail: Codeunit "Email Message";
        WhatsApp: Codeunit "WhatsApp Function";
    Begin
        if Type = Type::Customer then begin
            Customer.Reset();
            Customer.SetRange("No.", MasterCOde);
            if Customer.FindFirst() then begin
                SMTPemail.Create(Customer."E-Mail", 'Welcome Email - SFPL', '', true);
                SMTPemail.AppendToBody(Text001 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody(Text002 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Your Business Account has been created and please refer to your business account no. ' + Customer."No." + ' in future for any query.' + ',' + '<BR>');
                SMTPemail.AppendToBody(Text004 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Regards' + ',' + '<BR>');
                SMTPemail.AppendToBody('Sampoorna Feeds Pvt. Ltd' + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Note: This is the system generated email do not reply on this.' + ',' + '<BR>');
                EmailR.Send(SMTPemail, Enum::"Email Scenario"::Default);
                WhatsApp.AirtelWhatssAppAPI(WhatsApp.WhatsupSmsforWelcome(Customer."WhatsApp Mobile No.", Customer."No.", '01kj9mt4asas4ck4x7p0nssk7e'));
            end;
        end;
        if Type = Type::Vendor then begin
            Vendor.Reset();
            Vendor.SetRange("No.", MasterCOde);
            if Vendor.FindFirst() then begin
                SMTPemail.Create(Vendor."E-Mail", 'Welcome Email - SFPL', '', true);
                SMTPemail.AppendToBody(Text001 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody(Text002 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Your Business Account has been created and please refer to your business account no. ' + Vendor."No." + ' in future for any query.' + ',' + '<BR>');
                SMTPemail.AppendToBody(Text004 + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Regards' + ',' + '<BR>');
                SMTPemail.AppendToBody('Sampoorna Feeds Pvt. Ltd' + ',' + '<BR><BR>');
                SMTPemail.AppendToBody('Note: This is the system generated email do not reply on this.' + ',' + '<BR>');
                EmailR.Send(SMTPemail, Enum::"Email Scenario"::Default);
                WhatsApp.AirtelWhatssAppAPI(WhatsApp.WhatsupSmsforWelcome(Vendor."Phone No.", Vendor."No.", '01kj9mt4asas4ck4x7p0nssk7e'));
            end;
        end;
    end;

    // [EventSubscriber(ObjectType::Table, Database::Customer, OnAfterValidateEvent, 'P.A.N. No.', false, false)]
    // local procedure PANNoOnAfterValidateEvent(Rec: Record Customer)
    // begin
    //     if Rec."P.A.N. No." <> '' then
    //         VerifyPANDetails(Rec."No.", '35725367', rec."P.A.N. No.", Rec."API pan_type", rec."API Full Name", rec."API DOB", Rec."API aadhaar Seeding Status");
    //     Rec.Modify();
    // end;

    procedure VerifyPANDetails(No: Code[10]; refId: Text; panNumber: Text; var "APIpan_type": Text; var APIFullName: Text; Var APIDOB: text; var APIaadhaarSeedingStatus: text)
    var
        APIResponse: Text;
        Body: Text;
        JSONManagement: Codeunit "JSON Management";
        gResponseMsg: Text;
        gRequestMsg: Text;
        gContent: HttpContent;
        gContentHeaders: HttpHeaders;
        gHttpClient: HttpClient;
        JsonText: Text;
        gHttpResponseMsg: HttpResponseMessage;
        gHttpRequestMsg: HttpRequestMessage;
        Json: Text;
        Payload: Text;
        WebURL: Text;
        JsonDocument: JsonObject;
        DataElement: JsonToken;
        DataElement1: JsonToken;
        Customer: Record Customer;
        Vendor: Record Vendor;
        JWTPAYLOAD: text;
        Status: Text;
        UpdatePANNo: Codeunit "UpdatePANNo";

    begin
        CompanyInfo.Get();
        If Not CompanyInfo."Disable PAN Varification API" Then begin
            //Payload := '{"refid": "' + RefID + '", "pannumber": "' + panNumber + '"}';
            //WebURL := 'https://api.verifya2z.com/api/v1/verification/pan-advance';// Live
            Payload := '{"refid": "' + RefID + '", "id_number": "' + panNumber + '"}';
            WebURL := 'https://api.verifya2z.com/api/v1/verification/pandetails_verify';

            CLEAR(APIResponse);
            Clear(gResponseMsg);

            Clear(gResponseMsg);
            gContent.WriteFrom(Payload);
            gContent.GetHeaders(gContentHeaders);
            gContentHeaders.Clear();

            gContentHeaders.Add('Token', CreateJWT(CreateSprintVerifyPayload(), 'UTA5U1VEQXdNREF5TWpJd1QxUmpNVTlVWXpST1ZFbDRUbmM5UFE9PQ==', 'HS256', 30));
            gContentHeaders.Add('Content-Type', 'application/json');
            //gContentHeaders.Add('User-Agent', 'CORP00002220');
            gHttpClient.DefaultRequestHeaders.Add('User-Agent', 'CORP00002220');
            if gHttpClient.Post(WebURL, gContent, gHttpResponseMsg) then begin
                gHttpResponseMsg.Content.ReadAs(Json);
                if gHttpResponseMsg.IsSuccessStatusCode then begin

                    Status := UpdatePANNo.GetResponsesValue(Json, '"statuscode', ',', 1);
                    if Status <> '200' then
                        Error('%1', UpdatePANNo.GetResponsesValue(Json, '"message', ',', 1));
                    if not JsonDocument.ReadFrom(Json) then
                        Error('Invalid JSON format.');
                    if not JsonDocument.Get('data', DataElement) then
                        Error('JSON is missing the ''data'' element.');


                    "APIpan_type" := GetValueAsText(DataElement, 'category');
                    "APIFullName" := GetValueAsText(DataElement, 'fullName');
                    "APIDOB" := GetValueAsText(DataElement, 'dob');
                    If GetValueAsText(DataElement, 'aadhaarSeedingStatus') = 'NULL' then
                        "APIaadhaarSeedingStatus" := ''
                    else
                        "APIaadhaarSeedingStatus" := GetValueAsText(DataElement, 'aadhaarSeedingStatus');
                    ;



                end;
            END;
        end;
    END;

    procedure CreateSprintVerifyPayload(): JsonObject
    var
        Payload: JsonObject;
        JsonText: Text;
    begin
        // Create the JSON object
        Payload.Add('timestamp', GetCurrentUnixTimestamp()); // Unix timestamp in milliseconds
        Payload.Add('partnerId', 'CORP00002220');
        Payload.Add('reqid', Random(9999999)); // Ideally, generate a unique ID per request

        // Convert to text
        Payload.WriteTo(JsonText);
        exit(Payload);
    end;


    local procedure GetValueAsText(JsonToken: JsonToken; TKey: Text): Text
    var
        ValueToken: JsonToken;
    begin
        if JsonToken.AsObject().Get(TKey, ValueToken) then
            if not ValueToken.AsValue().IsNull then
                exit(ValueToken.AsValue().AsText());
        exit('');
    end;


    procedure CreateJWT(PayloadJsonInfo: JsonObject; SignKey: Text; Algorithm: Text; ExpireIn: Integer): Text
    var
        CryptographyMgt: Codeunit "Cryptography Management";
        BaseConvert: Codeunit "Base64 Convert";
        Header, Payload, Signature, JWTToken : Text;
        JWTHeaderLbl: Label '{"alg":"%1","typ":"JWT"}', Locked = true;
        JWTIssuedAtLbl: Label 'iat', Locked = true;
        JWTExpireInLbl: Label 'exp', Locked = true;
    begin

        PayloadJsonInfo.WriteTo(Payload);
        Header := BaseConvert.ToBase64(StrSubstNo(JWTHeaderLbl, Algorithm)).Replace('=', '');
        Payload := BaseConvert.ToBase64(Payload).Replace('=', '');
        JWTToken := Header + '.' + Payload;
        Signature := CryptographyMgt.GenerateHashAsBase64String(JWTToken, SignKey, Enum::"Hash Algorithm"::SHA256);
        Signature := Signature.Replace('=', '').Replace('/', '_').Replace('+', '-');
        exit(JWTToken + '.' + Signature);
    end;

    procedure GetCurrentUnixTimestamp(): Decimal
    var
        DateTime: DateTime;
    begin
        //DateTime := CurrentDateTime;
        exit(GetUnixTimeStampS(CurrentDateTime));

    end;

    procedure GetUnixTimeStampS(FromDateTime: DateTime): Decimal
    var
        TypeHelper: Codeunit "Type Helper";
        OriginalDateTIme: DateTime;
        TimeZoneOfSet: Duration;
        Results: Decimal;
    begin
        TypeHelper.GetUserTimezoneOffset(TimeZoneOfSet);
        OriginalDateTIme := System.CreateDateTime(DMY2Date(1, 1, 1970), 0T);
        OriginalDateTIme := OriginalDateTIme + TimeZoneOfSet;
        Results := FromDateTime - OriginalDateTIme;
        exit(Results);
    end;


    procedure ReopenFinishedProdOrder(var ProdOrder: Record "Production Order")
    var

    begin
        if not CanReopenFinishedProdOrder(ProdOrder) then
            Error('');

        ProcessProdOrderForReopen(ProdOrder);
        ShowReleasedProdOrderDocument(ProdOrder);

    end;

    local procedure CanReopenFinishedProdOrder(ProdOrder: Record "Production Order"): Boolean
    var
        ConfirmManagement: Codeunit "Confirm Management";
    begin
        exit(ConfirmManagement.GetResponseOrDefault(StrSubstNo(CanReOpenFinishedProdOrderQst, ProdOrder."No."), true));
    end;

    local procedure ProcessProdOrderForReopen(var ProdOrder: Record "Production Order")
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ValidateProdOrderHeaderForReopen(ProdOrder);
        TransferReopenProdOrder(ProdOrder);

        ProdOrderLine.SetRange(Status, ProdOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
        ProdOrderLine.SetFilter("Finished Quantity", '<>%1', 0);
        if ProdOrderLine.FindSet() then
            repeat
                ProcessProdOrderLineForReopen(ProdOrderLine);
            until ProdOrderLine.Next() = 0;

        TransferRelatedTablesToReleasedProdOrder(ProdOrder);
        ProdOrder.Delete();
    end;

    local procedure ShowReleasedProdOrderDocument(var ProdOrder: Record "Production Order")
    var
        NewProductionOrder: Record "Production Order";
    begin
        if not Confirm(StrSubstNo(OpenReleasedProdOrderQst, ProdOrder."No.")) then
            exit;

        NewProductionOrder.Get(NewProductionOrder.Status::Released, ProdOrder."No.");
        Page.Run(Page::"Released Production Order", NewProductionOrder);
    end;

    local procedure ValidateProdOrderHeaderForReopen(ProdOrder: Record "Production Order")
    begin
        ProdOrder.TestField(Status, ProdOrder.Status::Finished);
        if ProdOrder.Reopened then
            Error(ProductionOrderHasAlreadyBeenReopenedErr);

        // if CheckIfFinishedQtyIsZero(ProdOrder) then
        //     Error(ProductionOrderCannotBeReopenedErr);
    end;

    local procedure TransferReopenProdOrder(FromProdOrder: Record "Production Order")
    var
        ProductionOrder: Record "Production Order";
    begin
        ProductionOrder.Init();
        ProductionOrder := FromProdOrder;
        ProductionOrder.Status := ProductionOrder.Status::Released;
        ProductionOrder."Reopened" := true;
        ProductionOrder.Insert();

        //OnAfterTransferReopenProdOrder(ProductionOrder, FromProdOrder);
    end;

    local procedure ProcessProdOrderLineForReopen(ProdOrderLine: Record "Prod. Order Line")
    var
        UpdateProdOrderLine: Record "Prod. Order Line";
    begin
        ValidateProdOrderLineForReopen(ProdOrderLine);
        TransferReopenProdOrderLine(ProdOrderLine);
        TransReopenProdOrderComp(ProdOrderLine);
        UpdateSourceSubtypeForPutAwayDocumentWhenStatusIsChanged(ProdOrderLine, ProdOrderLine.Status::Released);
        //OnProcessProdOrderLineForReopenOnBeforeDeleteUpdateProdOrderLine(ProdOrderLine);
        UpdateProdOrderLine.Get(ProdOrderLine.Status, ProdOrderLine."Prod. Order No.", ProdOrderLine."Line No.");
        UpdateProdOrderLine.Delete();
    end;

    local procedure TransferRelatedTablesToReleasedProdOrder(ProdOrder: Record "Production Order")
    begin
        TransferReopenProdOrderRtngLine(ProdOrder);
        TransReopenProdOrderRtngTool(ProdOrder);
        TransReopenProdOrderRtngPersnl(ProdOrder);
        TransReopenProdOrdRtngQltyMeas(ProdOrder);
        TransReopenProdOrderCmtLine(ProdOrder);
        TransReopenProdOrderRtngCmtLn(ProdOrder);
        TransReopenProdOrderBOMCmtLine(ProdOrder);

        //OnAfterTransferRelatedTablesToReleasedProdOrder(ProdOrder);
    end;

    local procedure CheckIfFinishedQtyIsZero(ProdOrder: Record "Production Order"): Boolean
    var
        ProdOrderLine: Record "Prod. Order Line";
    begin
        ProdOrderLine.SetRange(Status, ProdOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
        ProdOrderLine.SetRange("Finished Quantity", 0);
        if not ProdOrderLine.IsEmpty() then
            exit(true);
    end;

    local procedure ValidateProdOrderLineForReopen(ProdOrderLine: Record "Prod. Order Line")
    begin
        ProdOrderLine.TestField(Status, ProdOrderLine.Status::Finished);
    end;

    local procedure TransferReopenProdOrderLine(FromProdOrderLine: Record "Prod. Order Line")
    var
        Item: Record Item;
        ProductionOrderLine: Record "Prod. Order Line";
        InvtAdjmtEntryOrder: Record "Inventory Adjmt. Entry (Order)";
    begin
        ProductionOrderLine.Init();
        ProductionOrderLine := FromProdOrderLine;
        ProductionOrderLine.Status := ProductionOrderLine.Status::Released;
        ProductionOrderLine.Insert();

        InvtAdjmtEntryOrder.Get(InvtAdjmtEntryOrder."Order Type"::Production, FromProdOrderLine."Prod. Order No.", FromProdOrderLine."Line No.");
        InvtAdjmtEntryOrder."Routing No." := ProductionOrderLine."Routing No.";
        InvtAdjmtEntryOrder."Cost is Adjusted" := false;
        InvtAdjmtEntryOrder."Is Finished" := false;
        InvtAdjmtEntryOrder.Modify();

        Item.Get(ProductionOrderLine."Item No.");
        Item."Cost is Adjusted" := false;
        Item.Modify();

        //OnAfterTransferReopenProdOrderLine(ProductionOrderLine, FromProdOrderLine);
    end;

    local procedure TransReopenProdOrderComp(FromProdOrderLine: Record "Prod. Order Line")
    var
        FromProdOrderComponent: Record "Prod. Order Component";
        NewProdOrderComponent: Record "Prod. Order Component";
    begin
        FromProdOrderComponent.SetRange(Status, FromProdOrderLine.Status);
        FromProdOrderComponent.SetRange("Prod. Order No.", FromProdOrderLine."Prod. Order No.");
        FromProdOrderComponent.SetRange("Prod. Order Line No.", FromProdOrderLine."Line No.");
        if FromProdOrderComponent.FindSet() then begin
            repeat
                NewProdOrderComponent.Init();
                NewProdOrderComponent := FromProdOrderComponent;
                NewProdOrderComponent.Status := NewProdOrderComponent.Status::Released;
                NewProdOrderComponent.Insert();
            until FromProdOrderComponent.Next() = 0;
            FromProdOrderComponent.DeleteAll();
        end;
    end;

    local procedure UpdateSourceSubtypeForPutAwayDocumentWhenStatusIsChanged(ProdOrderLine: Record "Prod. Order Line"; NewProdOrderStatus: Enum "Production Order Status")
    begin
        UpdateWhseActivityLineForProdOutput(ProdOrderLine, NewProdOrderStatus);
        UpdateWhseWorksheetLineForProdOutput(ProdOrderLine, NewProdOrderStatus);
    end;

    local procedure TransferReopenProdOrderRtngLine(FromProdOrder: Record "Production Order")
    var
        FromProdOrderRtngLine: Record "Prod. Order Routing Line";
        ToProdOrderRtngLine: Record "Prod. Order Routing Line";
    begin
        FromProdOrderRtngLine.SetRange(Status, FromProdOrder.Status);
        FromProdOrderRtngLine.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderRtngLine.FindSet() then begin
            repeat
                ToProdOrderRtngLine.Init();
                ToProdOrderRtngLine := FromProdOrderRtngLine;
                ToProdOrderRtngLine.Status := ToProdOrderRtngLine.Status::Released;
                ToProdOrderRtngLine."Routing Status" := ToProdOrderRtngLine."Routing Status"::"In Progress";
                ToProdOrderRtngLine.Insert();
            until FromProdOrderRtngLine.Next() = 0;
            FromProdOrderRtngLine.DeleteAll();
        end;
    end;

    local procedure TransReopenProdOrderRtngTool(FromProdOrder: Record "Production Order")
    var
        FromProdOrderRtngTool: Record "Prod. Order Routing Tool";
        ToProdOrderRoutTool: Record "Prod. Order Routing Tool";
    begin
        FromProdOrderRtngTool.SetRange(Status, FromProdOrder.Status);
        FromProdOrderRtngTool.SetRange("Prod. Order No.", FromProdOrder."No.");
        FromProdOrderRtngTool.LockTable();
        if FromProdOrderRtngTool.FindSet() then begin
            repeat
                ToProdOrderRoutTool := FromProdOrderRtngTool;
                ToProdOrderRoutTool.Status := ToProdOrderRoutTool.Status::Released;
                ToProdOrderRoutTool.Insert();
            until FromProdOrderRtngTool.Next() = 0;
            FromProdOrderRtngTool.DeleteAll();
        end;
    end;

    local procedure TransReopenProdOrderRtngPersnl(FromProdOrder: Record "Production Order")
    var
        FromProdOrderRtngPersonnel: Record "Prod. Order Routing Personnel";
        ToProdOrderRtngPersonnel: Record "Prod. Order Routing Personnel";
    begin
        FromProdOrderRtngPersonnel.SetRange(Status, FromProdOrder.Status);
        FromProdOrderRtngPersonnel.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderRtngPersonnel.FindSet() then begin
            repeat
                ToProdOrderRtngPersonnel.Init();
                ToProdOrderRtngPersonnel := FromProdOrderRtngPersonnel;
                ToProdOrderRtngPersonnel.Status := ToProdOrderRtngPersonnel.Status::Released;
                ToProdOrderRtngPersonnel.Insert();
            until FromProdOrderRtngPersonnel.Next() = 0;
            FromProdOrderRtngPersonnel.DeleteAll();
        end;
    end;

    local procedure TransReopenProdOrdRtngQltyMeas(FromProdOrder: Record "Production Order")
    var
        FromProdOrderRtngQltyMeas: Record "Prod. Order Rtng Qlty Meas.";
        ToProdOrderRtngQltyMeas: Record "Prod. Order Rtng Qlty Meas.";
    begin
        FromProdOrderRtngQltyMeas.SetRange(Status, FromProdOrder.Status);
        FromProdOrderRtngQltyMeas.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderRtngQltyMeas.FindSet() then begin
            repeat
                ToProdOrderRtngQltyMeas := FromProdOrderRtngQltyMeas;
                ToProdOrderRtngQltyMeas.Status := ToProdOrderRtngQltyMeas.Status::Released;
                ToProdOrderRtngQltyMeas.Insert();
            until FromProdOrderRtngQltyMeas.Next() = 0;
            FromProdOrderRtngQltyMeas.DeleteAll();
        end;
    end;

    local procedure TransReopenProdOrderCmtLine(FromProdOrder: Record "Production Order")
    var
        FromProdOrderCommentLine: Record "Prod. Order Comment Line";
        ToProdOrderCommentLine: Record "Prod. Order Comment Line";
        ToProdOrder: Record "Production Order";
    begin
        FromProdOrderCommentLine.SetRange(Status, FromProdOrder.Status);
        FromProdOrderCommentLine.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderCommentLine.FindSet() then begin
            repeat
                ToProdOrderCommentLine := FromProdOrderCommentLine;
                ToProdOrderCommentLine.Status := ToProdOrderCommentLine.Status::Released;
                ToProdOrderCommentLine.Insert();
            until FromProdOrderCommentLine.Next() = 0;
            FromProdOrderCommentLine.DeleteAll();
        end;
        TransferLinks(FromProdOrder, ToProdOrder);
    end;

    local procedure TransReopenProdOrderRtngCmtLn(FromProdOrder: Record "Production Order")
    var
        FromProdOrderRtngComment: Record "Prod. Order Rtng Comment Line";
        ToProdOrderRtngComment: Record "Prod. Order Rtng Comment Line";
    begin
        FromProdOrderRtngComment.SetRange(Status, FromProdOrder.Status);
        FromProdOrderRtngComment.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderRtngComment.FindSet() then begin
            repeat
                ToProdOrderRtngComment := FromProdOrderRtngComment;
                ToProdOrderRtngComment.Status := ToProdOrderRtngComment.Status::Released;
                ToProdOrderRtngComment.Insert();
            until FromProdOrderRtngComment.Next() = 0;
            FromProdOrderRtngComment.DeleteAll();
        end;
    end;

    local procedure TransReopenProdOrderBOMCmtLine(FromProdOrder: Record "Production Order")
    var
        FromProdOrderBOMComment: Record "Prod. Order Comp. Cmt Line";
        ToProdOrderBOMComment: Record "Prod. Order Comp. Cmt Line";
    begin
        FromProdOrderBOMComment.SetRange(Status, FromProdOrder.Status);
        FromProdOrderBOMComment.SetRange("Prod. Order No.", FromProdOrder."No.");
        if FromProdOrderBOMComment.FindSet() then begin
            repeat
                ToProdOrderBOMComment := FromProdOrderBOMComment;
                ToProdOrderBOMComment.Status := ToProdOrderBOMComment.Status::Released;
                ToProdOrderBOMComment.Insert();
            until FromProdOrderBOMComment.Next() = 0;
            FromProdOrderBOMComment.DeleteAll();
        end;
    end;

    local procedure UpdateWhseActivityLineForProdOutput(ProdOrderLine: Record "Prod. Order Line"; NewProdOrderStatus: Enum "Production Order Status")
    var
        WhseActivityLine: Record "Warehouse Activity Line";
    begin
        WhseActivityLine.SetLoadFields("Source Subtype");
        WhseActivityLine.SetRange("Activity Type", WhseActivityLine."Activity Type"::"Put-away");
        WhseActivityLine.SetRange("Source Type", Database::"Prod. Order Line");
        WhseActivityLine.SetRange("Source Subtype", ProdOrderLine.Status.AsInteger());
        WhseActivityLine.SetRange("Source Document", WhseActivityLine."Source Document"::"Prod. Output");
        WhseActivityLine.SetRange("Source No.", ProdOrderLine."Prod. Order No.");
        WhseActivityLine.SetRange("Source Line No.", ProdOrderLine."Line No.");
        WhseActivityLine.SetRange("Whse. Document Type", WhseActivityLine."Whse. Document Type"::Production);
        WhseActivityLine.SetRange("Whse. Document No.", ProdOrderLine."Prod. Order No.");
        WhseActivityLine.SetRange("Whse. Document Line No.", ProdOrderLine."Line No.");
        if not WhseActivityLine.IsEmpty() then
            WhseActivityLine.ModifyAll("Source Subtype", NewProdOrderStatus.AsInteger());
    end;

    local procedure UpdateWhseWorksheetLineForProdOutput(ProdOrderLine: Record "Prod. Order Line"; NewProdOrderStatus: Enum "Production Order Status")
    var
        WhseWorksheetLine: Record "Whse. Worksheet Line";
    begin
        WhseWorksheetLine.SetLoadFields("Source Subtype");
        WhseWorksheetLine.SetRange("Source Type", Database::"Prod. Order Line");
        WhseWorksheetLine.SetRange("Source Subtype", ProdOrderLine.Status.AsInteger());
        WhseWorksheetLine.SetRange("Source Document", WhseWorksheetLine."Source Document"::"Prod. Output");
        WhseWorksheetLine.SetRange("Source No.", ProdOrderLine."Prod. Order No.");
        WhseWorksheetLine.SetRange("Source Line No.", ProdOrderLine."Line No.");
        WhseWorksheetLine.SetRange("Whse. Document Type", WhseWorksheetLine."Whse. Document Type"::Production);
        WhseWorksheetLine.SetRange("Whse. Document No.", ProdOrderLine."Prod. Order No.");
        WhseWorksheetLine.SetRange("Whse. Document Line No.", ProdOrderLine."Line No.");
        if not WhseWorksheetLine.IsEmpty() then
            WhseWorksheetLine.ModifyAll("Source Subtype", NewProdOrderStatus.AsInteger());
    end;

    local procedure TransferLinks(FromProdOrder: Record "Production Order"; ToProdOrder: Record "Production Order")
    var
        RecordLink: Record "Record Link";
        PageManagement: Codeunit "Page Management";
        IsHandled: Boolean;
    begin

        RecordLink.SetRange("Record ID", FromProdOrder.RecordId);
        RecordLink.DeleteAll();

        RecordLink.SetRange("Record ID", ToProdOrder.RecordId);
        RecordLink.SetRange(Type, RecordLink.Type::Note);
        if RecordLink.FindSet(true) then
            repeat
                RecordLink.Validate(
                  URL1, GetUrl(DefaultClientType, CompanyName, OBJECTTYPE::Page, PageManagement.GetPageID(ToProdOrder), ToProdOrder));
                RecordLink.Validate(
                  Description,
                  StrSubstNo(
                    '%1 - %2 - %3',
                    PageManagement.GetPageCaption(PageManagement.GetPageID(ToProdOrder)),
                    ToProdOrder."No.", ToProdOrder.Description));
                RecordLink.Modify(true);
            until RecordLink.Next() = 0;
    end;



    procedure ActionApproval(DocNo: Code[20])
    var
        ReleaseSalesDoc: Codeunit "Release Sales Document";
        AppENtry: Record "Approval Entry";
    begin
        AppENtry.Reset();
        AppENtry.SetRange(Status, AppENtry.Status::Open);
        AppENtry.SetRange("Document No.", DocNo);
        if AppENtry.FindFirst() then
            AppENtry.DeleteAll();
    end;

    procedure RejectSalesApproval(DocNo: Code[20])
    var
        CheckApprovalEntry: Record "Approval Entry";
        DeleteApprovalEntry: Record "Approval Entry";
    begin
        CheckApprovalEntry.RESET;
        CheckApprovalEntry.SETRANGE(CheckApprovalEntry."Document No.", DocNo);
        CheckApprovalEntry.SETRANGE(CheckApprovalEntry."Sequence No.", 1);
        CheckApprovalEntry.SETRANGE(CheckApprovalEntry.Status, CheckApprovalEntry.Status::Rejected);
        IF CheckApprovalEntry.FINDFIRST THEN BEGIN
            DeleteApprovalEntry.RESET;
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry."Document No.", DocNo);
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry."Sequence No.", 1);
            DeleteApprovalEntry.SETRANGE(DeleteApprovalEntry.Status, DeleteApprovalEntry.Status::Open);
            IF DeleteApprovalEntry.FINDSET THEN
                DeleteApprovalEntry.DELETEALL;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Transfer Header", 'OnUpdateAllLineDimOnBeforeTransLineModify', '', true, true)]
    local procedure "Transfer Header_OnUpdateAllLineDimOnBeforeTransLineModify"(var TransLine: Record "Transfer Line")
    var
        TranH: Record "Transfer Header";
    begin
        if TranH.Get(TransLine."Document No.") then;
        TransLine."Shortcut Dimension 1 Code" := TranH."Shortcut Dimension 1 Code";
        TransLine."Shortcut Dimension 2 Code" := TranH."Shortcut Dimension 2 Code";
        TransLine.VALIDATE("Shortcut Dimension 3 Code", TranH."Shortcut Dimension 3 Code");  //PRU_RPG NDF_0.1
        TransLine.MODIFY;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Cust. Ledger Entry", 'OnAfterCopyCustLedgerEntryFromGenJnlLine', '', true, true)]
    local procedure "Cust. Ledger Entry_OnAfterCopyCustLedgerEntryFromGenJnlLine"
    (
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line"
    )
    var
        T480: Record 480;
    begin
        T480.RESET;//PRU-VG
        T480.SETRANGE("Dimension Set ID", GenJournalLine."Dimension Set ID");//PRU-VG
        T480.SETRANGE(T480."Dimension Code", 'LOC');//PRU-VG
        IF T480.FINDFIRST THEN//PRU-VG
            CustLedgerEntry."Shortcut Dimension 3 Code" := T480."Dimension Value Code";//PRU-VG
        CustLedgerEntry."Line Narration1" := GenJournalLine."Line Narration1"; // PRU_AS0.005 - 04 JULY 2019
        CustLedgerEntry.CustomerName := CustLedgerEntry."Customer Name";///PRU-VG
        CustLedgerEntry."Team Code" := GenJournalLine."Team Code";
        CustLedgerEntry."SFPL User ID" := GenJournalLine."User ID";
    end;


    [EventSubscriber(ObjectType::Table, Database::"G/L Entry", 'OnAfterCopyGLEntryFromGenJnlLine', '', true, true)]
    local procedure "G/L Entry_OnAfterCopyGLEntryFromGenJnlLine"
    (
        var GLEntry: Record "G/L Entry";
        var GenJournalLine: Record "Gen. Journal Line"
    )
    var
        T480: Record 480;
    begin
        //GLEntry."Line Narration" := GenJnlLine."Line Narration"; // PRU_AS0.005 - 05 JULY 2019
        GLEntry."Line Narration1" := GenJournalLine."Line Narration1"; // PRU_AS0.005 - 04 JULY 2019
        GLEntry."SFPL User ID" := GenJournalLine."User ID";
        T480.RESET;//PRU-VG
        T480.SETRANGE("Dimension Set ID", GenJournalLine."Dimension Set ID");//PRU-VG
        T480.SETRANGE(T480."Dimension Code", 'LOC');//PRU-VG
        IF T480.FINDFIRST THEN//PRU-VG
            GLEntry."Shortcut Dimension 3 Code" := T480."Dimension Value Code";//PRU-VG
        T480.RESET;//PRU-VG
        T480.SETRANGE("Dimension Set ID", GenJournalLine."Dimension Set ID");//PRU-VG
        T480.SETRANGE(T480."Dimension Code", 'EMPLOYEE');//PRU-VG
        IF T480.FINDFIRST THEN//PRU-VG
            GLEntry."Shortcut Dimension 4 Code" := T480."Dimension Value Code";//PRU-VG

    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterGetPurchSetup', '', true, true)]
    local procedure "Purchase Header_OnAfterGetPurchSetup"
    (
        PurchaseHeader: Record "Purchase Header";
        var PurchasesPayablesSetup: Record "Purchases & Payables Setup";
        CalledByFieldNo: Integer
    )
    var
        UserSetup: Record "User Setup";
    begin
        UserSetup.GET(USERID);
        UserSetup.TESTFIELD("Responsibility Center");
        PurchasesPayablesSetup.GET;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnInitFromPurchHeader', '', true, true)]
    local procedure "Purchase Header_OnInitFromPurchHeader"
    (
        var PurchaseHeader: Record "Purchase Header";
        SourcePurchaseHeader: Record "Purchase Header"
    )
    begin
    end;

    [EventSubscriber(ObjectType::Table, Database::"Production Order", 'OnBeforeCreateDim', '', true, true)]
    local procedure OnBeforeCreateDimProd(var ProductionOrder: Record "Production Order"; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterCopyBuyFromVendorFieldsFromVendor', '', true, true)]
    local procedure "Purchase Header_OnAfterCopyBuyFromVendorFieldsFromVendor"

    (var
    PurchaseHeader: Record "Purchase Header";
    Vendor: Record Vendor; xPurchaseHeader: Record "Purchase Header"
    )

    begin
        PurchaseHeader."POS as Vendor State" := Vendor."SFPL_POS as Vendor State";

    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnCopyFromItemOnAfterCheck', '', true, true)]
    local procedure "Purchase Line_OnCopyFromItemOnAfterCheck"
    (
        PurchaseLine: Record "Purchase Line";
        Item: Record "Item";
        CallingFieldNo: Integer
    )
    var
        PHRec: Record "Purchase Header";
    begin
        PurchaseLine."Chicks Item" := Item."Chicks Item"; //PRU-RK
        //PurchaseLine."Tax Free" := Item."Tax Free";//PRU_NEELESH 1.1
        PurchaseLine."Item Type" := Item."Item Type";//PRU-VG

    end;



    [EventSubscriber(ObjectType::Table, Database::"Purchase Line", 'OnValidateQtyToReceiveOnAfterInitQty', '', true, true)]
    local procedure "Purchase Line_OnValidateQtyToReceiveOnAfterInitQty"
    (
        var PurchaseLine: Record "Purchase Line";
        var xPurchaseLine: Record "Purchase Line";
        CallingFieldNo: Integer;
        var IsHandled: Boolean
    )
    var
        Text008: Label 'You cannot receive more than %1 units.';
        Text009: Label 'You cannot receive more than %1 base units.';
        Item_Rec: Record Item;
    begin
        //GULSHAN 201217
        CompanyInfo.GET();
        if Companyinfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then
            IF NOT PurchaseLine.Subcontracting THEN BEGIN
                IF PurchaseLine."Quantity Received" = 0 THEN BEGIN
                    IF PurchaseLine."Qty. to Receive" > PurchaseLine.Quantity + PurchaseLine."Quantity Received" THEN BEGIN
                        IF PurchaseLine.Type = PurchaseLine.Type::Item THEN
                            Item_Rec.GET(PurchaseLine."No.");
                        PurchaseLine."Extra Quantity" := PurchaseLine.Quantity * Item_Rec."Item Tolerance" / 100;
                    END;
                    IF (((PurchaseLine."Qty. to Receive" < 0) XOR (PurchaseLine.Quantity < 0)) AND (PurchaseLine.Quantity <> 0) AND (PurchaseLine."Qty. to Receive" <> 0)) OR
                       (ABS(PurchaseLine."Qty. to Receive") > ABS(PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity")) OR //gulshan
                       (((PurchaseLine.Quantity < 0) XOR (PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity" < 0)) AND (PurchaseLine.Quantity <> 0) AND (PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity" <> 0)) //GULSHAN
                    THEN
                        ERROR(
                          Text008,
                          PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity");
                    IF (((PurchaseLine."Qty. to Receive (Base)" < 0) XOR (PurchaseLine."Quantity (Base)" < 0)) AND (PurchaseLine."Qty. to Receive (Base)" <> 0) AND (PurchaseLine."Quantity (Base)" <> 0)) OR
                     (ABS(PurchaseLine."Qty. to Receive (Base)") > ABS(PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity")) OR //gulshan
                     (((PurchaseLine."Quantity (Base)" < 0) XOR (PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity" < 0)) AND (PurchaseLine."Quantity (Base)" <> 0) AND (PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity" <> 0)) //GULSHAN
                  THEN
                        ERROR(
                          Text009,
                          PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity");

                END ELSE
                    IF PurchaseLine."Qty. to Receive" > PurchaseLine.Quantity - PurchaseLine."Quantity Received" THEN BEGIN
                        IF PurchaseLine.Type = PurchaseLine.Type::Item THEN
                            Item_Rec.GET(PurchaseLine."No.");
                        PurchaseLine."Extra Quantity" := PurchaseLine.Quantity * Item_Rec."Item Tolerance" / 100;

                        IF (((PurchaseLine."Qty. to Receive" < 0) XOR (PurchaseLine.Quantity < 0)) AND (PurchaseLine.Quantity <> 0) AND (PurchaseLine."Qty. to Receive" <> 0)) OR
                           (ABS(PurchaseLine."Qty. to Receive") > ABS(PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity")) OR //gulshan
                           (((PurchaseLine.Quantity < 0) XOR (PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity" < 0)) AND (PurchaseLine.Quantity <> 0) AND (PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity" <> 0)) //GULSHAN
                        THEN
                            ERROR(
                              Text008,
                              PurchaseLine."Outstanding Quantity" + PurchaseLine."Extra Quantity");
                        IF (((PurchaseLine."Qty. to Receive (Base)" < 0) XOR (PurchaseLine."Quantity (Base)" < 0)) AND (PurchaseLine."Qty. to Receive (Base)" <> 0) AND (PurchaseLine."Quantity (Base)" <> 0)) OR
                         (ABS(PurchaseLine."Qty. to Receive (Base)") > ABS(PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity")) OR //gulshan
                         (((PurchaseLine."Quantity (Base)" < 0) XOR (PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity" < 0)) AND (PurchaseLine."Quantity (Base)" <> 0) AND (PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity" <> 0)) //GULSHAN
                      THEN
                            ERROR(
                              Text009,
                        PurchaseLine."Outstanding Qty. (Base)" + PurchaseLine."Extra Quantity");
                    END;
            END ELSE
                PurchaseLine.ValidateQuantity;
        IsHandled := true;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterGetSalesSetup', '', true, true)]
    local procedure "Sales Header_OnAfterGetSalesSetup"
    (
        SalesHeader: Record "Sales Header";
        var SalesReceivablesSetup: Record "Sales & Receivables Setup";
        CalledByFieldNo: Integer
    )
    var
        UserSetup: Record 91;
    begin
        UserSetup.GET(USERID);
        UserSetup.TESTFIELD("Responsibility Center");
        //  SalesReceivablesSetup.GET;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnCopyFromItemOnAfterCheck', '', true, true)]
    local procedure "Sales Line_OnCopyFromItemOnAfterCheck"
    (
        var SalesLine: Record "Sales Line";
        Item: Record "Item"
    )
    var
        SalesHeader_T: Record "Sales Header";
        SalesHeader: Record "Sales Header";
    begin

        SalesLine."Chicks Item" := Item."Chicks Item"; //PRU-RK
        SalesLine."Item Type" := Item."Item Type";
        if SalesHeader.get(SalesLine."Document Type", SalesLine."Document No.") then
            SalesLine."Location State Code" := SalesHeader."Location State Code";
        //Pru_gk
    end;




    [EventSubscriber(ObjectType::Table, Database::"Vendor Ledger Entry", 'OnAfterCopyVendLedgerEntryFromGenJnlLine', '', true, true)]
    local procedure "Vendor Ledger Entry_OnAfterCopyVendLedgerEntryFromGenJnlLine"
    (
        var VendorLedgerEntry: Record "Vendor Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line"
    )
    var
        T480: Record 480;
        Vendor: Record 23;
        PurchaseInvHeader: Record "Purch. Inv. Header";
        PurcaseCrHeader: Record "Purch. Cr. Memo Hdr.";
    begin
        VendorLedgerEntry."Creditors Type" := GenJournalLine."Creditors Type"; //PruRaj
        VendorLedgerEntry."Line Narration1" := GenJournalLine."Line Narration1";
        T480.RESET;//PRU-VG
        T480.SETRANGE("Dimension Set ID", GenJournalLine."Dimension Set ID");//PRU-VG
        T480.SETRANGE(T480."Dimension Code", 'LOC');//PRU-VG
        IF T480.FINDFIRST THEN//PRU-VG
            VendorLedgerEntry."Shortcut Dimension 3Code" := T480."Dimension Value Code";

        VendorLedgerEntry.VendorName := VendorLedgerEntry."Vendor Name";

        PurchaseInvHeader.Reset();
        PurchaseInvHeader.SetRange("No.", VendorLedgerEntry."Document No.");
        if PurchaseInvHeader.FindFirst() then
            VendorLedgerEntry."Mandi Name" := PurchaseInvHeader."Mandi Name"
        else begin
            PurcaseCrHeader.Reset();
            PurcaseCrHeader.SetRange("No.", VendorLedgerEntry."Document No.");
            if PurcaseCrHeader.FindFirst() then
                VendorLedgerEntry."Mandi Name" := PurcaseCrHeader."Mandi Name";
        end;
        VendorLedgerEntry."Creditors Type" := GenJournalLine."Creditors Type"; //PruRaj
        VendorLedgerEntry."Line Narration1" := GenJournalLine."Line Narration1";//PRU_NEELESH
        VendorLedgerEntry."Security Group Code" := GenJournalLine."Security Group Code";// Suman
        VendorLedgerEntry."SFPL User ID" := GenJournalLine."User ID";

    end;


    local procedure GSTCalculatedAmount(PurchaseLine: Record "Purchase Line"): Decimal;
    var
        GSTSetup: Record "GST Setup";
        PurchaseHeader: Record "Purchase Header";
        GSTGroup: Record "GST Group";
        TransactionGSTAmount: Decimal;
        TransactionCessAmount: Decimal;
        GSTAmountToBeLoaded: Decimal;
        CustomDuty: Decimal;
        Sign: Integer;
        GSTBaseValidation: Codeunit "GST Base Validation";
        GSTNonAvailmentSessionMgt: Codeunit "GST Non Availment Session Mgt";
        ItemLedEntry: Record "Item Ledger Entry";
        DocNo: Code[100];
    begin
        if not GSTSetup.Get() then
            exit;

        if not PurchaseHeader.Get(PurchaseLine."Document Type", PurchaseLine."Document No.") then
            exit;

        if not GSTGroup.Get(PurchaseLine."GST Group Code") then
            exit;

        if PurchaseLine."GST Credit" = PurchaseLine."GST Credit"::"Non-Availment" then
            TransactionGSTAmount := GetTaxAmount(GSTSetup."GST Tax Type", PurchaseLine.RecordId);


        if (PurchaseHeader."GST Vendor Type" in [PurchaseHeader."GST Vendor Type"::Import, PurchaseHeader."GST Vendor Type"::SEZ]) and
            (PurchaseLine."GST Credit" = PurchaseLine."GST Credit"::"Non-Availment") and
            (PurchaseLine."Custom Duty Amount" <> 0) and
            not (PurchaseHeader."Document Type" in [PurchaseHeader."Document Type"::"Credit Memo", PurchaseHeader."Document Type"::"Return Order"]) then begin
            CustomDuty := PurchaseLine."Custom Duty Amount";
            if PurchaseHeader."Currency Code" <> '' then
                CustomDuty := ConvertCustomDutyAmountToLCY(
                                PurchaseHeader."Currency Code",
                                PurchaseLine."Custom Duty Amount",
                                PurchaseHeader."Currency Factor",
                                PurchaseHeader."Posting Date");

            GSTNonAvailmentSessionMgt.SetCustomDutyAmount(CustomDuty);
        end else
            GSTNonAvailmentSessionMgt.SetCustomDutyAmount(0);

        if (GSTSetup."Cess Tax Type" <> '') and (GSTGroup."Cess Credit" = GSTGroup."Cess Credit"::"Non-Availment") then
            TransactionCessAmount := GetTaxAmount(GSTSetup."Cess Tax Type", PurchaseLine.RecordId);

        if (TransactionGSTAmount + TransactionCessAmount) <> 0 then
            GSTAmountToBeLoaded := GSTBaseValidation.RoundGSTPrecision((TransactionGSTAmount + TransactionCessAmount) * (PurchaseLine."Qty. to Invoice" / PurchaseLine.Quantity));

        if PurchaseLine."Document Type" in [PurchaseLine."Document Type"::Order,
            PurchaseLine."Document Type"::Invoice,
            PurchaseLine."Document Type"::Quote,
            PurchaseLine."Document Type"::"Blanket Order"] then
            Sign := 1
        else
            Sign := -1;

        exit(GSTAmountToBeLoaded * Sign);
    end;

    local procedure ConvertCustomDutyAmountToLCY(CurrencyCode: Code[10]; Amount: Decimal; CurrencyFactor: Decimal; PostingDate: Date): Decimal
    var
        CurrencyExchangeRate: Record "Currency Exchange Rate";
        GeneralLedgerSetup: Record "General Ledger Setup";
        TaxComponent: Record "Tax Component";
        GSTSetup: Record "GST Setup";
    begin
        if not GSTSetup.Get() then
            exit;

        if CurrencyCode <> '' then begin
            GeneralLedgerSetup.Get();
            GSTSetup.TestField("GST Tax Type");
            GeneralLedgerSetup.TestField("Custom Duty Component Code");
            TaxComponent.SetRange("Tax Type", GSTSetup."GST Tax Type");
            TaxComponent.SetRange(name, Format(GeneralLedgerSetup."Custom Duty Component Code"));
            TaxComponent.FindFirst();
            exit(Round(CurrencyExchangeRate.ExchangeAmtFCYToLCY(PostingDate, CurrencyCode, Amount, CurrencyFactor), TaxComponent."Rounding Precision"));
        end;
    end;

    local procedure GetTaxAmount(TaxType: Code[20]; PurchaseLineTaxID: RecordId): Decimal
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        TaxAmount: Decimal;
        Code: Codeunit 22;
    begin
        TaxTransactionValue.Reset();
        TaxTransactionValue.SetRange("Tax Type", TaxType);
        TaxTransactionValue.SetRange("Tax Record ID", PurchaseLineTaxID);
        TaxTransactionValue.SetFilter(Percent, '<>%1', 0);
        if TaxTransactionValue.FindSet() then
            repeat
                TaxAmount += RoundTaxAmount(TaxType, TaxTransactionValue."Value ID", TaxTransactionValue."Amount (LCY)");
            until TaxTransactionValue.Next() = 0;

        exit(TaxAmount);
    end;

    procedure RoundTaxAmount(TaxType: Code[20]; ID: Integer; TaxAmt: Decimal): Decimal
    var
        TaxComponent: Record "Tax Component";
        RoundedValue: Decimal;
        GSTRoundingDirection: Text[1];
    begin
        TaxComponent.Reset();
        TaxComponent.SetRange("Tax Type", TaxType);
        TaxComponent.SetRange(ID, ID);
        TaxComponent.SetFilter("Rounding Precision", '<>%1', 0);
        if TaxComponent.FindFirst() then begin
            case TaxComponent.Direction of
                TaxComponent.Direction::Nearest:
                    GSTRoundingDirection := '=';
                TaxComponent.Direction::Up:
                    GSTRoundingDirection := '>';
                TaxComponent.Direction::Down:
                    GSTRoundingDirection := '<';
            end;

            RoundedValue := Round(TaxAmt, TaxComponent."Rounding Precision", GSTRoundingDirection);
            exit(RoundedValue);
        end;

        exit(TaxAmt);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemJnlLineOnBeforeItemJnlPostLineRunWithCheck', '', false, false)]
    local procedure LoadGSTUnitCost(PurchaseHeader: Record "Purchase Header"; PurchaseLine: Record "Purchase Line"; var ItemJnlLine: Record "Item Journal Line"; QtyToBeInvoiced: Decimal)
    var
        QtyFactor: Decimal;
        CustomDutyAmount: Decimal;
        PurchLineGSTAmount: Decimal;
    begin
        if PurchaseLine."GST Credit" = PurchaseLine."GST Credit"::"Non-Availment" then
            //exit;
            PurchLineGSTAmount := GSTCalculatedAmount(PurchaseLine);
        if PurchLineGSTAmount <> 0 then
            exit;

        if PurchaseLine."Custom Duty Amount" = 0 then
            exit;

        if PurchaseLine."Qty. to Invoice" <> 0 then
            QtyFactor := QtyToBeInvoiced / PurchaseLine."Qty. to Invoice";

        if PurchaseHeader."Currency Code" <> '' then
            CustomDutyAmount := ConvertCustomDutyAmountToLCY(
                            PurchaseHeader."Currency Code",
                            PurchaseLine."Custom Duty Amount",
                            PurchaseHeader."Currency Factor",
                            PurchaseHeader."Posting Date")
        else
            CustomDutyAmount := PurchaseLine."Custom Duty Amount";

        if (PurchaseHeader."GST Vendor Type" in
            [PurchaseHeader."GST Vendor Type"::SEZ, PurchaseHeader."GST Vendor Type"::Import]) and
            (CustomDutyAmount <> 0) and (PurchaseLine."Qty. to Invoice" <> 0) then
            ItemJnlLine.Amount := ItemJnlLine.Amount + CustomDutyAmount / PurchaseLine."Qty. to Invoice" * ItemJnlLine."Invoiced Quantity";

        if QtyToBeInvoiced <> 0 then
            ItemJnlLine."Unit Cost" := ItemJnlLine."Unit Cost" + ((CustomDutyAmount) * QtyFactor / QtyToBeInvoiced)
        else
            if (PurchaseLine."Qty. to Receive" > PurchaseLine."Qty. to Invoice") and (PurchaseLine."Qty. to Invoice" <> 0) and PurchaseHeader.Invoice then
                ItemJnlLine."Unit Cost" := ItemJnlLine."Unit Cost" + ((CustomDutyAmount) * QtyFactor / PurchaseLine."Qty. to Invoice");
    end;



    procedure DrillDownFarmThisMonth()
    var
        UserSetup: Record "User Setup";
        ILE: Record "Item Ledger Entry";

    begin
        UserSetup.GET(USERID);
        ILE.SETRANGE("Item Type", ILE."Item Type"::Feed);
        ILE.SETRANGE("Location Code", UserSetup."Shortcut Dimension 3 Code");
        ILE.SETFILTER("Remaining Quantity", '<>%1', 0);
        ILE.SETRANGE("Posting Date", CALCDATE('<-CM>', WORKDATE), WORKDATE);
        PAGE.RUN(PAGE::"Item Ledger Entries", ILE);

    end;

    procedure DrillDownBirdThisMonth()
    var
        UserSetup: Record "User Setup";
        ILE: Record "Item Ledger Entry";
    begin
        UserSetup.GET(USERID);
        ILE.SETRANGE("Item Type", ILE."Item Type"::Bird);
        ILE.SETRANGE("Location Code", UserSetup."Shortcut Dimension 3 Code");
        ILE.SETFILTER("Remaining Quantity", '<>%1', 0);
        ILE.SETRANGE("Posting Date", CALCDATE('<-CM>', WORKDATE), WORKDATE);
        PAGE.RUN(PAGE::"Item Ledger Entries", ILE);
    end;

    procedure DrillDownChickThisMonth()
    var
        UserSetup: Record "User Setup";
        ILE: Record "Item Ledger Entry";
    begin
        UserSetup.GET(USERID);
        ILE.SETRANGE("Item Type", ILE."Item Type"::Chick);
        ILE.SETRANGE("Location Code", UserSetup."Shortcut Dimension 3 Code");
        ILE.SETFILTER("Remaining Quantity", '<>%1', 0);
        ILE.SETRANGE("Posting Date", CALCDATE('<-CM>', WORKDATE), WORKDATE);
        PAGE.RUN(PAGE::"Item Ledger Entries", ILE);
    end;

    procedure DrillDownEggThisMonth()
    var
        UserSetup: Record "User Setup";
        ILE: Record "Item Ledger Entry";
    begin
        UserSetup.GET(USERID);
        ILE.SETRANGE("Item Type", ILE."Item Type"::Egg);
        ILE.SETRANGE("Location Code", UserSetup."Shortcut Dimension 3 Code");
        ILE.SETFILTER("Remaining Quantity", '<>%1', 0);
        ILE.SETRANGE("Posting Date", CALCDATE('<-CM>', WORKDATE), WORKDATE);
        PAGE.RUN(PAGE::"Item Ledger Entries", ILE);
    end;
    //SIM -----Code Added---->>>>>>----------
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', false, false)]
    procedure UpdateILEEntryInfo(var NewItemLedgEntry: Record "Item Ledger Entry"; var ItemJournalLine: Record "Item Journal Line"; var ItemLedgEntryNo: Integer)
    var
        Location: Record Location;
    begin
        NewItemLedgEntry.Consumption := ItemJournalLine.Consumption;
        Location.get(ItemJournalLine."Location Code");
        NewItemLedgEntry."Region Code" := Location."Region Code";
        NewItemLedgEntry."SFPL User ID" := ItemJournalLine.SFPLUserID;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitValueEntry', '', false, false)]
    procedure UpdateValueEntryInfo(var ValueEntry: Record "Value Entry"; var ItemJournalLine: Record "Item Journal Line"; var ValueEntryNo: Integer; var ItemLedgEntry: Record "Item Ledger Entry")
    begin
        ValueEntry.Consumption := ItemJournalLine.Consumption;
    end;

    procedure CreateInventoryPostingSetups(LocRec: Record Location);
    var
        myInt: Integer;
        InvPostGroup: Record "Inventory Posting Group";
        Bajra: Label 'BAJRA';
        DimenMaster: Record "Dimension Master";
        DimensionValue: Record "Dimension Value";
    begin
        // repeat
        case LocRec."Responsibility Center" of
            'FEED':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BAJRA');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076240', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BREEDER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076280', '1077210', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076910', '1077210', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CATTLE FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076930', '1077230', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CONSUMABLE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'DORB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076260', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'ELECTRICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'FEED SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076310', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GOAT FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076940', '1077240', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'INGREDIENT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076270', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'LAYER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076920', '1077220', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MAIZE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076210', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MECHNICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076300', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OIL AND LUB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER CONSUMABLE MAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER MATERIAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076960', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PIG FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076950', '1077250', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1077620', '1077810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PP BAGS-FD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1077610', '1077810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PREMIX');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076290', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PRINTING STATIONERY');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'RICE KANI');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076230', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SCRAP');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078010', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SOYA DOC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076250', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'WHEAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076220', '1076810', '1078050')

                end;
            'BREEDER':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BREEDER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078730', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078730', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'COMM EGG-BRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079210', '1079120', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CONSUMABLE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CRACK EGG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079220', '1079120', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'DORB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'ELECTRICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'FEED SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078750', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079650', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'HAT EGG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079010', '1079120', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'INGREDIENT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076270', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'JUMBO EGG -BRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079230', '1079120', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'LAYER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078730', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MAIZE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078730', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MECHNICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MISHAP EGG-BRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079240', '1079120', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078740', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER CONSUMABLE MAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER MATERIAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078750', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PARENT BIRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078720', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PARENT CHICK');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078710', '1078910', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079610', '1079620', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PRINTING STATIONERY');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'WASTE EGG-BRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079250', '1079120', '1078050')

                end;
            'CATTLE':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BAJRA');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076240', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BREEDER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076280', '1077210', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076910', '1077210', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CATTLE FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076930', '1077230', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CONSUMABLE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'DORB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076260', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'ELECTRICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'FEED SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076310', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GOAT FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076940', '1077240', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'INGREDIENT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076270', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'LAYER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076920', '1077220', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MAIZE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076210', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MECHNICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076300', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OIL AND LUB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER CONSUMABLE MAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER MATERIAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076960', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PIG FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076950', '1077250', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1077620', '1077810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PP BAGS-FD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1077610', '1077810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PREMIX');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076290', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PRINTING STATIONERY');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'RICE KANI');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076230', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SCRAP');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078010', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1078030', '1078040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SOYA DOC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076250', '1076810', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'WHEAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1076220', '1076810', '1078050')
                end;
            'CBF':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER BIRD');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1095010', '1095610', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091020', '1093020', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CHICKS');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091010', '1093010', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CONSUMABLE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'ELECTRICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'FEED SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091040', '1093040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097070', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'INGREDIENT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091040', '1093030', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'LAYER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091020', '1093020', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MAIZE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091050', '1093030', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091030', '1093030', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OIL AND LUB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER MATERIAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER CONSUMABLE MAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER SUPPL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091050', '1093040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097030', '1097040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PREMIX');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1091050', '1093030', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PRINTING STATIONERY');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SCRAP');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097010', '1097060', '1078050');

                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MECHNICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1097050', '1097060', '1078050')
                end;
            'HATCH':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CHICKS');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1084010', '1084610', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CONSUMABLE');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CRACK EGG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1086020', '1086620', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'ELECTRICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'GEN ITEM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'HAT EGG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1082010', '1083020', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'INFERT EGG-HAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1086010', '1086610', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MECHNICAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1079630', '1079640', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1082020', '1083020', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OIL AND LUB');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER CONSUMABLE MAT');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'OTHER MATERIAL');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088010', '1088020', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PRINTING STATIONERY');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1088030', '1088040', '1078050');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SCRAP');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '1086030', '1088040', '1078050')

                end;
        End;
        // until LocRec.Next() = 0;

        DimensionValue.Reset();
        DimensionValue.SetRange("Dimension Code", 'LOC');
        DimensionValue.SetRange(Code, LocRec.Code);
        if not DimensionValue.FindFirst() then begin
            DimensionValue.Init();
            DimensionValue."Dimension Code" := 'LOC';
            DimensionValue.Validate("Global Dimension No.", 3);
            DimensionValue.Code := LocRec.Code;
            DimensionValue.Name := LocRec.Name;
            DimensionValue.Insert();
        end;

        DimenMaster.Reset();
        DimenMaster.SetRange("Shortcut Dimension 3 Code", LocRec.Code);
        if not DimenMaster.FindFirst() then begin
            DimenMaster.Init();
            DimenMaster."Shortcut Dimension 1 Code" := LocRec."Responsibility Center";
            DimenMaster."Shortcut Dimension 2 Code" := LocRec."Shortcut Dimension 2 Code";
            DimenMaster."Shortcut Dimension 3 Code" := LocRec.Code;
            DimenMaster.Insert();
        end;


    end;

    procedure CreateInventoryPostingSetupsForStarFoods(LocRec: Record Location);
    var
        myInt: Integer;
        InvPostGroup: Record "Inventory Posting Group";
        Bajra: Label 'BAJRA';
        DimenMaster: Record "Dimension Master";
        DimensionValue: Record "Dimension Value";
    begin
        // repeat
        case LocRec."Responsibility Center" of
            'CBF':
                begin
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'BROILER FEED');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106977', '106980', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CHICKS');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106976', '106979', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'MED & VACC');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106978', '106981', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'CON');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106500', '106600', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'EI');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106650', '106700', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'FG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106750', '105800', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'PM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106300', '106400', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'RM');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '105500', '105600', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'SFG');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '105900', '106000', '106900');
                    InvPostGroup.Reset();
                    InvPostGroup.SetRange(Code, 'WA');
                    if InvPostGroup.FindFirst() then
                        InsertInvPostGroup(LocRec.Code, InvPostGroup.Code, '106750', '106800', '106900');

                end;
        End;
    end;

    procedure InsertInvPostGroup(LocCode: Code[50]; InvPosGrp: Code[50]; InvAcc: Code[20]; InvAccInterim: Code[20]; WIPAcc: Code[20])
    var
        InvPostSetup: Record "Inventory Posting Setup";

    begin

        CompanyInfo.Get;
        InvPostSetup.Reset();
        InvPostSetup.SetRange("Location Code", LocCode);
        InvPostSetup.SetRange("Invt. Posting Group Code", InvPosGrp);
        if not InvPostSetup.FindFirst() then begin
            InvPostSetup.Init();
            InvPostSetup."Location Code" := LocCode;
            InvPostSetup."Invt. Posting Group Code" := InvPosGrp;
            InvPostSetup."Inventory Account" := InvAcc;
            InvPostSetup."Inventory Account (Interim)" := InvAccInterim;
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then
                InvPostSetup."Unrealized Profit Account" := '1328100';
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] then
                InvPostSetup."Unrealized Profit Account" := '316100';
            InvPostSetup."WIP Account" := WIPAcc;
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then
                InvPostSetup."Material Variance Account" := '1324500';
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] then
                InvPostSetup."Material Variance Account" := '304600';
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then
                InvPostSetup."Mfg. Overhead Variance Account" := '1325000';
            If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] then
                InvPostSetup."Mfg. Overhead Variance Account" := '304700';
            InvPostSetup.Insert();
        end;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnPostItemChargePerTransferOnBeforePostItemJnlLine', '', false, false)]
    local procedure PurchPostOnPostItemChargePerTransferOnBeforePostItemJnlLine(
        var PurchLine: Record "Purchase Line";
        ItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)")

    var
        GSTAmountLoaded: Decimal;
    begin
        Clear(QtyToAssign);
        QtyToAssign := ItemChargeAssignmentPurch."Qty. to Assign";
    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Item Charge Assgnt. (Purch.)", 'OnAssignEquallyOnBeforeItemChargeAssignmentPurchModify', '', False, False)]
    local procedure UpdateSFPLQtytoAssign(var ItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)")
    var

    begin
        ItemChargeAssignmentPurch."SFPL_QTY to Assign" := ItemChargeAssignmentPurch."Qty. to Assign";


    end;

    [EventSubscriber(ObjectType::Codeunit, CodeUnit::"Item Charge Assgnt. (Purch.)", 'OnAssignByAmountOnBeforeItemChargeAssignmentPurchModify', '', False, False)]
    local procedure UpdateSFPLQtytoAssignequelly(var ItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)")
    var

    begin
        ItemChargeAssignmentPurch."SFPL_QTY to Assign" := ItemChargeAssignmentPurch."Qty. to Assign";


    end;

    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterInitRecord', '', False, False)]
    local procedure UpdateOrderDate(var PurchHeader: Record "Purchase Header")
    begin
        PurchHeader."Order Date" := Today;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnBeforeValidateEvent', 'HSN/SAC Code', False, False)]
    local procedure OnBeforeValidateHSNCode(var Rec: Record "Sales Line")
    var
        HSNCode: Record "HSN/SAC";
        Items: Record Item;
        GLAccount: Record "G/L Account";
        ChargeItems: Record "Item Charge";
        FixedAssets: Record "Fixed Asset";

    begin
        If Rec."GST Group Type" in [Rec."GST Group Type"::Goods] Then begin
            HSNCode.Reset();
            HSNCode.SetRange(HSNCode.Code, Rec."HSN/SAC Code");
            if HSNCode.FindFirst() then
                if StrLen(HSNCode.Code) < 8 then
                    Error('Please update the Valid HSN Code with 8 Digit')
        end;

    end;


    [EventSubscriber(ObjectType::Table, Database::Item, 'OnBeforeValidateEvent', 'HSN/SAC Code', False, False)]
    local procedure OnBeforeValidateHSNCodeonItems(var Rec: Record Item)
    var
        HSNCode: Record "HSN/SAC";
        Items: Record Item;
        GLAccount: Record "G/L Account";
        ChargeItems: Record "Item Charge";
        FixedAssets: Record "Fixed Asset";
    begin

        HSNCode.Reset();
        HSNCode.SetRange(HSNCode.Code, Rec."HSN/SAC Code");
        if HSNCode.FindFirst() then
            if Rec.Type = Rec.Type::Inventory Then
                if StrLen(HSNCode.Code) < 8 then
                    Error('Please update the Valid HSN Code with 8 Digit')

    end;

    [EventSubscriber(ObjectType::Table, Database::Item, 'OnBeforeValidateEvent', 'Inventory Posting Group', False, False)]
    local procedure ModifyInventorypostingGroup(var Rec: Record Item)
    var

    begin

        Rec.TestNoEntriesExist(Rec.FieldCaption(Rec."Inventory Posting Group"));

    end;

    [EventSubscriber(ObjectType::Table, Database::Item, 'OnBeforeValidateEvent', 'Gen. Prod. Posting Group', False, False)]
    local procedure ModifyGenProdpostingGroup(var Rec: Record Item)
    var

    begin

        Rec.TestNoEntriesExist(Rec.FieldCaption(Rec."Gen. Prod. Posting Group"));

    end;

    [EventSubscriber(ObjectType::Table, Database::Item, 'OnBeforeValidateEvent', 'Item Category Code', False, False)]
    local procedure ModifyItemCatagoryCOde(var Rec: Record Item)
    var

    begin

        Rec.TestNoEntriesExist(Rec.FieldCaption(Rec."Item Category Code"));

    end;

    [EventSubscriber(ObjectType::Table, DataBase::Item, OnafterValidateEvent, 'Description', false, false)]
    local procedure OnafterValidateeventDescription(Var Rec: Record "Item"; Xrec: Record "Item")
    Var
        Item: Record Item;
    begin

        Rec.Description := UpperCase(Rec.Description);

        Item.Reset();
        Item.SetRange(Description, Rec.Description);
        if Item.FindFirst() then
            if Item.Description = Rec.Description then
                Error('Item Name already exist, please check the Item No. %1', Item."No.");

    end;



    [EventSubscriber(ObjectType::Table, Database::"Fixed Asset", 'OnBeforeValidateEvent', 'HSN/SAC Code', False, False)]
    local procedure OnBeforeValidateHSNCodeonFixedAssets(var Rec: Record "Fixed Asset")
    var
        HSNCode: Record "HSN/SAC";
        Items: Record Item;
        GLAccount: Record "G/L Account";
        ChargeItems: Record "Item Charge";
        FixedAssets: Record "Fixed Asset";
    begin

        HSNCode.Reset();
        HSNCode.SetRange(HSNCode.Code, Rec."HSN/SAC Code");
        if HSNCode.FindFirst() then
            if StrLen(HSNCode.Code) < 8 then
                Error('Please update the Valid HSN Code with 8 Digit')

    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Line", 'OnBeforeValidateEvent', 'No.', False, False)]
    local procedure OnBeforeValidateHSNNo(var Rec: Record "Sales Line")
    var
        HSNCode: Record "HSN/SAC";
        Items: Record Item;
        GLAccount: Record "G/L Account";
        ChargeItems: Record "Item Charge";
        FixedAssets: Record "Fixed Asset";
    begin
        if Rec."GST Group Type" = rec."GST Group Type"::Goods Then Begin
            case Rec.Type of
                Rec.Type::Item:
                    begin
                        Items.Reset();
                        items.SetRange("No.", rec."No.");
                        Items.SetFilter("HSN/SAC Code", '<>%1', '');
                        Items.SetRange(Type, Items.Type::Inventory);
                        if Items.FindFirst() Then begin
                            HSNCode.Reset();
                            HSNCode.SetRange(HSNCode.Code, Items."HSN/SAC Code");
                            if HSNCode.FindFirst() then
                                if StrLen(HSNCode.Code) < 8 then
                                    Error('Please update the Valid HSN Code with 8 Digit')
                        end;
                    End;
                Rec.Type::"G/L Account":
                    begin
                        GLAccount.Reset();
                        GLAccount.SetRange("No.", rec."No.");
                        GLAccount.SetFilter("HSN/SAC Code", '<>%1', '');
                        if GLAccount.FindFirst() Then begin
                            HSNCode.Reset();
                            HSNCode.SetRange(HSNCode.Code, GLAccount."HSN/SAC Code");
                            if HSNCode.FindFirst() then
                                if StrLen(HSNCode.Code) < 8 then
                                    Error('Please update the Valid HSN Code with 8 Digit')
                        end;
                    end;
                Rec.Type::"Fixed Asset":
                    begin
                        FixedAssets.Reset();
                        FixedAssets.SetRange("No.", rec."No.");
                        FixedAssets.SetFilter("HSN/SAC Code", '<>%1', '');
                        if FixedAssets.FindFirst() Then begin
                            HSNCode.Reset();
                            HSNCode.SetRange(HSNCode.Code, FixedAssets."HSN/SAC Code");
                            if HSNCode.FindFirst() then
                                if StrLen(HSNCode.Code) < 8 then
                                    Error('Please update the Valid HSN Code with 8 Digit')
                        end;
                    end;
                Rec.Type::"Charge (Item)":
                    begin
                        ChargeItems.Reset();
                        ChargeItems.SetRange("No.", rec."No.");
                        ChargeItems.SetFilter("HSN/SAC Code", '<>%1', '');
                        if ChargeItems.FindFirst() Then begin
                            HSNCode.Reset();
                            HSNCode.SetRange(HSNCode.Code, ChargeItems."HSN/SAC Code");
                            if HSNCode.FindFirst() then
                                if StrLen(HSNCode.Code) < 8 then
                                    Error('Please update the Valid HSN Code with 8 Digit')
                        end;
                    end;
            End;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Transfer Line", 'OnBeforeValidateEvent', 'Item No.', False, False)]
    local procedure OnBeforeValidateHSNNoTRansfer(var Rec: Record "Transfer Line")
    var
        HSNCode: Record "HSN/SAC";
        Items: Record Item;
        GLAccount: Record "G/L Account";
        ChargeItems: Record "Item Charge";
        FixedAssets: Record "Fixed Asset";

    begin

        Items.Reset();
        items.SetRange("No.", rec."Item No.");
        Items.SetFilter("HSN/SAC Code", '<>%1', '');
        Items.SetRange(Type, Items.Type::Inventory);
        if Items.FindFirst() Then begin
            HSNCode.Reset();
            HSNCode.SetRange(HSNCode.Code, Items."HSN/SAC Code");
            if HSNCode.FindFirst() then
                if StrLen(HSNCode.Code) < 8 then
                    Error('Please update the Valid HSN Code with 8 Digit')
        end;
    end;




    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeSaveTempWhseSplitSpec', '', false, false)]
    local procedure OnBeforeSaveTempWhseSplitSpec(TransLine: Record "Transfer Line"; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line"; var IsHandled: Boolean)
    var
        Item: Record Item;
    begin
        Item.Get(TransLine."Item No.");
        if Item."Item Tracking Code" = '' then
            IsHandled := true;

    end;

    [EventSubscriber(ObjectType::Table, 36, 'onaftervalidateevent', 'Ship-to Code', false, false)]
    local procedure ShipToAddrfields(Var Rec: Record "Sales Header")
    var
        ShipToAddress: Record "Ship-to Address";
        ShipToGSTARNErr: Label 'Either Ship-To Address GST Registration No. or ARN No. in Ship-To Address should have a value.';
        CompanyInfo: record "Company Information";
    begin
        CompanyInfo.Get;
        If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] Then begin
            if Rec."GST Customer Type" <> "GST Customer Type"::" " then
                if Rec."GST Customer Type" in [
                    "GST Customer Type"::Exempted,
                    "GST Customer Type"::"Deemed Export",
                    "GST Customer Type"::"SEZ Development",
                    "GST Customer Type"::"SEZ Unit",
                    "GST Customer Type"::Registered]
                then begin
                    if Rec."Ship-to Code" <> '' Then
                        ShipToAddress.Get(Rec."Sell-to Customer No.", Rec."Ship-to Code");
                    If Rec."Ship-to Code" <> '' Then begin
                        ShipToAddress.TestField(State);
                        // if ShipToAddress."GST Registration No." = '' then
                        //     if ShipToAddress."ARN No." = '' then
                        //         Error(ShiptoGSTARNErr);
                        Rec."GST Ship-to State Code" := ShipToAddress.State;
                        Rec."Ship-to GST Reg. No." := ShipToAddress."GST Registration No.";
                        Rec."GST-Ship to Customer Type" := ShipToAddress."Ship-to GST Customer Type";
                        Rec."Ship-to GST Customer Type" := ShipToAddress."Ship-to GST Customer Type";

                        if CheckGSTPlaceOfSupply(Rec) then
                            Rec.State := ShipToAddress.State;
                    end else begin
                        Rec."GST Ship-to State Code" := '';
                        Rec."Ship-to GST Reg. No." := '';

                    end;
                    //AssignInvoiceType(SalesHeader);
                end;
        end;
    end;


    local Procedure CheckGSTPlaceOfSupply(SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetRange("GST Place of Supply", SalesLine."GST Place of Supply"::"Ship-to Address");
        if not SalesLine.IsEmpty() then
            exit(true);

        exit(false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterInitItemLedgEntry', '', true, true)]
    local procedure "Item Jnl.-Post Line_OnAfterInitItemLedgEntry"
        (
            var NewItemLedgEntry: Record "Item Ledger Entry";
            var ItemJournalLine: Record "Item Journal Line";
            var ItemLedgEntryNo: Integer
        )
    var
        Loc: Record Location;
        Item: Record Item;
        T480: Record 480;
        ProdOrder: Record "Production Order";
    begin
        NewItemLedgEntry."Chicks Item" := ItemJournalLine."Chicks Item"; //RK-PRU
        Loc.GET(ItemJournalLine."Location Code");//PRU-VG
        NewItemLedgEntry."Location Name" := Loc.Name;//PRU-VG
        if ItemJournalLine."Order Type" = ItemJournalLine."Order Type"::Production then begin
            ProdOrder.Get(ProdOrder.Status::Released, ItemJournalLine."Document No.");
            NewItemLedgEntry."Bardana Generation Entry" := ItemJournalLine."Bardana Generation Entry";
        end;

        NewItemLedgEntry."Shortcut Dimension 3 Code" := ItemJournalLine."Shortcut Dimension 3 Code"; ///Pru_gk
        NewItemLedgEntry."Alternate Quantity" := ItemJournalLine."Alternate Quantity";//PRU-VG
        NewItemLedgEntry."Alternate UOM" := ItemJournalLine."Alternate UOM";//PRU-VG
        NewItemLedgEntry."Weak Mortality" := ItemJournalLine."Weak Mortality";//PRU-VG
        NewItemLedgEntry."Data Entry Sheet No." := ItemJournalLine."Data Entry Sheet No.";//PRU-VG
        NewItemLedgEntry."Transit Mortality" := ItemJournalLine."Transit Mortality";//PRU-VG
        NewItemLedgEntry."In-transit Mortality" := ItemJournalLine."In-transit Mortality"; ////Pru_gk
        NewItemLedgEntry."Exclude Quantity of Mortality" := ItemJournalLine."Exclude Quantity of Mortality";//PRU-VG
        NewItemLedgEntry."Flock No." := ItemJournalLine."Flock No.";//PRU-VG
        NewItemLedgEntry."Item Type" := ItemJournalLine."Item Type";//PRU-VG
        NewItemLedgEntry."Debit Note Type" := ItemJournalLine."Debit Note Type";
        if Item.Get(ItemJournalLine."Item No.") then;
        NewItemLedgEntry."Item Name" := Item.Description;//PRU-VG

        //PRU-Vg 4.0
        NewItemLedgEntry."Rejected For Item Tracking" := ItemJournalLine.Rejected;
        NewItemLedgEntry.Fertility := ItemJournalLine.Fertility;
        NewItemLedgEntry.Age := ItemJournalLine.Age;
        NewItemLedgEntry."Breed Code" := ItemJournalLine."Breed Code";
        NewItemLedgEntry."Lay Day Comment" := ItemJournalLine."Lay Day Comment";
        NewItemLedgEntry."Apply Entry" := ItemJournalLine."Apply Entry";// SUMAN 08022025
        //PRU-VG 4.0
        //>>PRU_RPG MNF_0.1
        NewItemLedgEntry."Data Entry Type" := ItemJournalLine."Data Entry Type";
        NewItemLedgEntry."Laying Entry Type" := ItemJournalLine."Laying Entry Type";
        NewItemLedgEntry."Hatching Entry Type" := ItemJournalLine."Hatching Entry Type";
        NewItemLedgEntry."Descriptive Entry Type" := ItemJournalLine."Descriptive Entry Type";
        //<<PRU_RPG MNF_0.1
        T480.RESET;//PRU-VG
        T480.SETRANGE("Dimension Set ID", ItemJournalLine."Dimension Set ID");//PRU-VG
        T480.SETRANGE(T480."Dimension Code", 'LOC');//PRU-VG
        IF T480.FINDFIRST THEN//PRU-VG
            NewItemLedgEntry."Shortcut Dimension 3 Code" := T480."Dimension Value Code";//PRU-VG
                                                                                        //     NewItemLedgEntry."Item Type" := Item."Item Type";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", OnCodeOnBeforeRunCheck, '', True, True)]
    local procedure CheckDimension(var ItemJnlCheckLine: Codeunit "Item Jnl.-Check Line"; var ItemJnlLine: Record "Item Journal Line")
    var
        ItemJn: Record "Item Journal Line";
        DefaultDimension: Record "Default Dimension";
        Dimensetentry: Record "Dimension Set Entry";
        GLSetup: Record "General Ledger Setup";
        Dimension: Record Dimension;
        RemQty: Decimal;
        ILE: Record "Item Ledger Entry";
    begin
        //ItemJnlLine.TestField(ItemJnlLine."Shortcut Dimension 1 Code");
        //ItemJnlLine.TestField(ItemJnlLine."Shortcut Dimension 2 Code");
        if ItemJnlLine."Journal Batch Name" <> '' Then begin
            DefaultDimension.Reset();
            DefaultDimension.SetRange("Table ID", 27);
            DefaultDimension.SetRange("No.", ItemJnlLine."Item No.");
            DefaultDimension.SetRange("Value Posting", DefaultDimension."Value Posting"::"Code Mandatory");
            if DefaultDimension.FindFirst() then
                repeat
                    Dimensetentry.SetRange("Dimension Set ID", ItemJnlLine."Dimension Set ID");
                    Dimensetentry.SetRange("Dimension Code", DefaultDimension."Dimension Code");
                    Dimensetentry.SetFilter("Dimension Value Code", '<>%1', '');
                    if not Dimensetentry.FindFirst() then
                        Error('%1 is mandatory for account code %2', DefaultDimension."Dimension Code", DefaultDimension."No.");

                UNTIL DefaultDimension.Next() = 0;

            DefaultDimension.Reset();
            DefaultDimension.SetRange("Table ID", 27);
            DefaultDimension.SetRange("Value Posting", DefaultDimension."Value Posting"::"Code Mandatory");
            if DefaultDimension.FindFirst() then
                repeat
                    Dimensetentry.SetRange("Dimension Set ID", ItemJnlLine."Dimension Set ID");
                    Dimensetentry.SetRange("Dimension Code", DefaultDimension."Dimension Code");
                    Dimensetentry.SetFilter("Dimension Value Code", '<>%1', '');
                    if not Dimensetentry.FindFirst() then
                        Error('%1 is mandatory for Item No. code %2', DefaultDimension."Dimension Code", DefaultDimension."No.");
                UNTIL DefaultDimension.Next() = 0;

            DefaultDimension.Reset();
            DefaultDimension.SetRange("Table ID", 83);
            DefaultDimension.SetRange("Value Posting", DefaultDimension."Value Posting"::"Code Mandatory");
            if DefaultDimension.FindFirst() then
                repeat
                    Dimensetentry.SetRange("Dimension Set ID", ItemJnlLine."Dimension Set ID");
                    Dimensetentry.SetRange("Dimension Code", DefaultDimension."Dimension Code");
                    Dimensetentry.SetFilter("Dimension Value Code", '<>%1', '');
                    if not Dimensetentry.FindFirst() then
                        Error('%1 is mandatory for account code %2', DefaultDimension."Dimension Code", DefaultDimension."No.");
                UNTIL DefaultDimension.Next() = 0;
        end;
        CLEAR(RemQty);
        ILE.RESET;
        ILE.SETRANGE("Item No.", ItemJnlLine."Item No.");
        ILE.SETRANGE("Posting Date", 0D, ItemJnlLine."Posting Date");
        ILE.SETRANGE("Location Code", ItemJnlLine."Location Code");
        IF ILE.FINDSET THEN BEGIN
            ILE.CALCSUMS("Remaining Quantity");
            RemQty := ILE."Remaining Quantity";
        END;


        if ((ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Transfer)) Then
            if (ItemJnlLine."Document Type" = ItemJnlLine."Document Type"::"Transfer Shipment") Then
                if ItemJnlLine."Applies-from Entry" = 0 then
                    IF RemQty < ItemJnlLine.Quantity THEN
                        ERROR('Stock not available of Item No %1 of %2 Location', ItemJnlLine."Item No.", ItemJnlLine."Location Code");


    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterPurchCrMemoLineInsert', '', true, true)]
    local procedure OnAfterPurchCrMemoLineInsert(var PurchCrMemoLine: Record "Purch. Cr. Memo Line"; var PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."; var PurchLine: Record "Purchase Line"; CommitIsSupressed: Boolean; var PurchaseHeader: Record "Purchase Header"; GenJnlLineDocNo: Code[20]; RoundingLineInserted: Boolean; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line")
    var
    begin

        PurchCrMemoLine."TDS Section Code" := PurchLine."TDS Section Code";
        PurchCrMemoLine.Modify();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeFinalizePosting', '', true, true)]
    local procedure OnBeforeDeleteAfterPostingPurchaseOrder(var PurchaseHeader: Record "Purchase Header"; var TempPurchLineGlobal: Record "Purchase Line" temporary; var EverythingInvoiced: Boolean; CommitIsSupressed: Boolean; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line")
    var


    begin
        If PurchaseHeader.IsTemporary Then
            exit;
        if (PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Order) or (PurchaseHeader."PO Type" = PurchaseHeader."PO Type"::Goods) then
            EverythingInvoiced := False;

    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Purchase Document Lines", 'OnAfterCopyLineToDoc', '', true, true)]
    local procedure "Posted Purchase Document Lines_OnAfterCopyLineToDoc"(var PurchaseHeader: Record "Purchase Header")
    var
        SaleLine: Record "Purchase Line";
        SaleLine1: Record "Purchase Line";

    begin
        SaleLine.Reset();
        SaleLine.SetRange("Document No.", PurchaseHeader."No.");
        SaleLine.SetFilter(Type, '<>%1', SaleLine.Type::" ");
        SaleLine.SetRange(Exempted, true);
        if SaleLine.FindFirst() then
            repeat
                SaleLine."GST Exempt" := true;
                SaleLine.Validate(Quantity);
                SaleLine.Validate("GST Credit");
                SaleLine.Modify();
                SaleLine1.Reset();
                SaleLine1.SetRange("Document No.", PurchaseHeader."No.");
                SaleLine1.SetRange(Type, SaleLine1.Type::" ");
                if SaleLine1.FindFirst() then
                    repeat
                        SaleLine1.Exempted := true;
                        SaleLine1."GST Exempt" := true;
                        //   SaleLine1."GST Credit" := SaleLine."GST Credit";
                        SaleLine1.Modify();
                    until SaleLine1.Next() = 0;
            until SaleLine.Next() = 0;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnRunOnBeforeFinalizePosting', '', true, true)]
    local procedure "Purch.-Post_OnRunOnBeforeFinalizePosting"
        (
            var PurchaseHeader: Record "Purchase Header";
            var PurchRcptHeader: Record "Purch. Rcpt. Header";
            var PurchInvHeader: Record "Purch. Inv. Header";
            var PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
            var ReturnShipmentHeader: Record "Return Shipment Header";
            var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
            CommitIsSuppressed: Boolean
        )
    var

        RecILE: Record "Item Ledger Entry";
        Flag: Boolean;
        ReturnShipmentHeader11: Record "Return Shipment Header";
        PurchRcptHeader11: Record "Purch. Rcpt. Header";
        PurchInvHeader11: Record "Purch. Inv. Header";
        PurchCrMemoHdr11: Record "Purch. Cr. Memo Hdr.";
        PurchRcptHeader1: Record "Purch. Rcpt. Header";
        GLEntry: Record "G/L Entry";
        SAlrec: Record "Sales & Receivables Setup";
        DetailGstENtry: Record "Detailed GST Ledger Entry";
        ReturnShipmentLine11: Record "Return Shipment Line";
        PurchInvLine11: Record "Purch. Inv. Line";
        PurchCrMemoLine11: Record "Purch. Cr. Memo Line";
        PurchRcptLine1: Record "Purch. Rcpt. Line";
        GSTLedEntry: Record "GST Ledger Entry";
        ItemRec: Record Item;
        PILRec: Record "Purch. Inv. Line";
        PCLRec: Record "Purch. Cr. Memo Line";
        GenPostSetup: record "General Posting Setup";
        GLENtry1: Record 17;
        AMT: Decimal;
        AMT1: Decimal;
        DetGstLedEn: Record "Detailed GST Ledger Entry";
        detAmt: Decimal;
        detAmt1: Decimal;
        PILRec1: Record "Purch. Inv. Line";
        PCLRec1: Record "Purch. Cr. Memo Line";
        ItemCha: Decimal;
        OtherItem: Decimal;
        ItemCha1: Decimal;
        OtherItem1: Decimal;
        VLE: Record "Value Entry";
        TDSEntries: Record "TDS Entry";
        PITDS: Record "Purch. Inv. Line";
        PCTDS: Record "Purch. Cr. Memo Line";

    begin
        if PurchInvHeader."No." <> '' Then begin
            PITDS.Reset();
            PITDS.SetRange("Document No.", PurchInvHeader."No.");
            PITDS.SetFilter("TDS Section Code", '<>%1', '');
            If PITDS.FindFirst() then begin
                TDSEntries.Reset();
                TDSEntries.SetRange("Document No.", PITDS."Document No.");
                if TDSEntries.IsEmpty then
                    Error('TDS Entry Must be Generated');
            end;
        end;
        if PurchCrMemoHdr."No." <> '' Then begin
            PCTDS.Reset();
            PCTDS.SetRange("Document No.", PurchCrMemoHdr."No.");
            PCTDS.SetFilter("TDS Section Code", '<>%1', '');
            If PCTDS.FindFirst() then begin
                TDSEntries.Reset();
                TDSEntries.SetRange("Document No.", PCTDS."Document No.");
                if TDSEntries.IsEmpty then
                    Error('TDS Entry Must be Generated');
            end;
        end;


        if (PurchInvHeader."No." <> '') and (PurchInvHeader."Vendor GST Reg. No." <> PurchInvHeader."Location GST Reg. No.") then begin
            PILRec1.Reset();
            PILRec1.SetRange("Document No.", PurchInvHeader."No.");
            PILRec1.SetFilter("No.", '<>%1', '');
            PILRec1.SetFilter("GST Group Code", '<>%1', '');
            PILRec1.SetFilter("HSN/SAC Code", '<>%1', '');
            PILRec1.SetFilter(Quantity, '<>%1', 0);
            if PILRec1.FindSet() then
                repeat
                    DetGstLedEn.Reset();
                    DetGstLedEn.SetRange("Document No.", PurchInvHeader."No.");
                    DetGstLedEn.SetRange("Document Line No.", PILRec1."Line No.");
                    //DetGstLedEn.SetFilter("Buyer/Seller Reg. No.", '<>%1', PurchInvHeader."Location GST Reg. No.");
                    if DetGstLedEn.IsEmpty then
                        Error('GST Amount not calculated');

                Until PILRec1.Next() = 0;
        end;
        if (PurchCrMemoHdr."No." <> '') and (PurchCrMemoHdr."Vendor GST Reg. No." <> PurchCrMemoHdr."Location GST Reg. No.") then begin
            PCLRec.Reset();
            PCLRec.SetRange("Document No.", PurchCrMemoHdr."No.");
            PCLRec.SetFilter("No.", '<>%1', '');
            PCLRec.SetFilter("GST Group Code", '<>%1', '');
            PCLRec.SetFilter("HSN/SAC Code", '<>%1', '');
            PCLRec.SetFilter(Quantity, '<>%1', 0);
            if PCLRec.FindSet() then
                repeat
                    DetGstLedEn.Reset();
                    DetGstLedEn.SetRange("Document No.", PurchCrMemoHdr."No.");
                    DetGstLedEn.SetRange("Document Line No.", PCLRec."Line No.");
                    if DetGstLedEn.IsEmpty then
                        Error('GST Amount not calculated');
                Until PCLRec.Next() = 0;
        end;


    END;


    [EventSubscriber(ObjectType::Table, Database::"Purchase Header", 'OnAfterPurchaseLinesEditable', '', true, true)]
    local procedure "Purchase Header_OnAfterPurchaseLinesEditable"
    (
        PurchaseHeader: Record "Purchase Header";
        var IsEditable: Boolean
    )
    begin
        IsEditable := true;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnAfterCopyPurchaseDocument', '', true, true)]
    local procedure "Copy Document Mgt._OnAfterCopyPurchaseDocument"
    (
        FromDocumentType: Option;
        FromDocumentNo: Code[20];
        var ToPurchaseHeader: Record "Purchase Header";
        FromDocOccurenceNo: Integer;
        FromDocVersionNo: Integer;
        IncludeHeader: Boolean;
        RecalculateLines: Boolean;
        MoveNegLines: Boolean
    )
    var
        PORec: Record "Purchase Header";
        PRH: Record "Purch. Rcpt. Header";
        PIH: Record "Purch. Inv. Header";
        PCM: Record "Purch. Cr. Memo Hdr.";
        SIH: Record "Sales Invoice Header";
        SCM: Record "Sales Cr.Memo Header";
        SSH: Record "Sales Shipment Header";
        PurchasHe: Record "Purchase Header";
    begin
        //  Message('%1..%2..%3..%4..%5', FromDocumentType, FromDocumentNo, ToPurchaseHeader."Shortcut Dimension 1 Code", ToPurchaseHeader."Shortcut Dimension 2 Code", ToPurchaseHeader."Shortcut Dimension 3 Code");
        if PRH.Get(FromDocumentNo) then begin
            ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", PRH."Shortcut Dimension 1 Code");
            ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", PRH."Shortcut Dimension 2 Code");
            ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", PRH."Shortcut Dimension 3 Code");
        end else
            if PIH.Get(FromDocumentNo) then begin
                ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", PIH."Shortcut Dimension 1 Code");
                ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", PIH."Shortcut Dimension 2 Code");
                ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", PIH."Shortcut Dimension 3 Code");
            end else
                if PCM.Get(FromDocumentNo) then begin
                    ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", PCM."Shortcut Dimension 1 Code");
                    ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", PCM."Shortcut Dimension 2 Code");
                    ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", PCM."Shortcut Dimension 3 Code");
                END else
                    if SIH.Get(FromDocumentNo) then begin
                        ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", SIH."Shortcut Dimension 1 Code");
                        ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", SIH."Shortcut Dimension 2 Code");
                        ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", SIH."Shortcut Dimension 3 Code");
                    END else
                        if SCM.Get(FromDocumentNo) then begin
                            ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", SCM."Shortcut Dimension 1 Code");
                            ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", SCM."Shortcut Dimension 2 Code");
                            ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", SCM."Shortcut Dimension 3 Code");
                        END else
                            if SSH.Get(FromDocumentNo) then begin
                                ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", SSH."Shortcut Dimension 1 Code");
                                ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", SSH."Shortcut Dimension 2 Code");
                                ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", SSH."Shortcut Dimension 3 Code");
                            END;
        PurchasHe.Reset();
        PurchasHe.SetRange("No.", FromDocumentNo);
        if PurchasHe.FindFirst() then begin
            ToPurchaseHeader.Validate("Shortcut Dimension 1 Code", PurchasHe."Shortcut Dimension 1 Code");
            ToPurchaseHeader.Validate("Shortcut Dimension 2 Code", PurchasHe."Shortcut Dimension 2 Code");
            ToPurchaseHeader.Validate("Shortcut Dimension 3 Code", PurchasHe."Shortcut Dimension 3 Code");
        end;

    end;





    [EventSubscriber(ObjectType::Codeunit, Codeunit::"User Setup Management", 'OnBeforeGetLocation', '', true, true)]
    local procedure "User Setup Management_OnBeforeGetLocation"
    (
        DocType: Option;
        AccLocation: Code[10];
        RespCenterCode: Code[10];
        var LocationCode: Code[10];
        var IsHandled: Boolean
    )
    var
        UserSetup: Record "User Setup";
    begin
        UserSetup.GET(USERID);
        if UserId <> 'JOBQUEUE' Then
            if UserSetup."Shortcut Dimension 3 Code" <> '' then begin
                LocationCode := UserSetup."Shortcut Dimension 3 Code";
                IsHandled := true;
            END else
                IsHandled := false;

        //  END;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnCheckExternalDocumentNumberOnAfterSetFilters', '', true, true)]
    local procedure "Purch.-Post_OnCheckExternalDocumentNumberOnAfterSetFilters"
    (
        var VendLedgEntry: Record "Vendor Ledger Entry";
        PurchaseHeader: Record "Purchase Header"
    )
    var
        F_StartDate1: Date;
        F_EndDate1: Date;
        TempYear: Integer;
        TempMonth: Integer;
    begin
        CLEAR(F_StartDate1);
        CLEAR(F_EndDate1);
        //F_StartDate1 := FinancialStartDate;
        //F_EndDate1 := FinancialEndDate;

        CLEAR(TempYear);
        CLEAR(TempMonth);
        TempYear := DATE2DMY(PurchaseHeader."Posting Date", 3);
        TempMonth := DATE2DMY(PurchaseHeader."Posting Date", 2);
        IF (TempMonth = 1) OR (TempMonth = 2) OR (TempMonth = 3) THEN BEGIN
            F_StartDate1 := DMY2DATE(1, 4, (TempYear - 1));
            F_EndDate1 := DMY2DATE(31, 3, (TempYear));
        END ELSE BEGIN
            F_StartDate1 := DMY2DATE(1, 4, (TempYear));
            F_EndDate1 := DMY2DATE(31, 3, (TempYear + 1));
        END;
        IF (F_StartDate1 <> 0D) AND (F_EndDate1 <> 0D) THEN     //PRU_RPG 26Sept2018
            VendLedgEntry.SETRANGE("Posting Date", F_StartDate1, F_EndDate1);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeItemJnlPostLine', '', true, true)]
    local procedure "Purch.-Post_OnBeforeItemJnlPostLine"
 (
     var ItemJournalLine: Record "Item Journal Line";
     PurchaseLine: Record "Purchase Line";
     PurchaseHeader: Record "Purchase Header";
     CommitIsSupressed: Boolean;
     var IsHandled: Boolean;
     WhseReceiptHeader: Record "Warehouse Receipt Header";
     WhseShipmentHeader: Record "Warehouse Shipment Header";
     TempItemChargeAssignmentPurch: Record "Item Charge Assignment (Purch)";
     TempWarehouseReceiptHeader: Record "Warehouse Receipt Header";
     PurchInvHeader: Record "Purch. Inv. Header";
     PurchCrMemoHeader: Record "Purch. Cr. Memo Hdr."
 )
    begin
        //  ItemJnlLine."Shortcut Dimension 3 Code" := PurchHeader."Shortcut Dimension 3 Code";  ///Pru_gk
        ItemJournalLine."Chicks Item" := PurchaseLine."Chicks Item"; //PRU-RK
        ItemJournalLine."Alternate Quantity" := PurchaseLine."Alternate Quantity";//PRU-VG
        ItemJournalLine."Alternate UOM" := PurchaseLine."Alternate UOM";//PRU-VG
        ItemJournalLine."Flock No." := PurchaseLine."Flock No.";//PRU-VG
        ItemJournalLine."Item Type" := PurchaseLine."Item Type";//PRU-VG
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnBeforeInsertItemLedgEntry', '', true, true)]
    local procedure "Item Jnl.-Post Line_OnBeforeInsertItemLedgEntry"
    (
        var ItemLedgerEntry: Record "Item Ledger Entry";
        ItemJournalLine: Record "Item Journal Line";
        TransferItem: Boolean
    )
    var
        Item: Record Item;
        Cust: Record Customer;
    begin
        ItemLedgerEntry."Chicks Item" := ItemJournalLine."Chicks Item"; //PRU-RK
        ItemLedgerEntry."Alternate Quantity" := ItemJournalLine."Alternate Quantity";//PRU-VG
        ItemLedgerEntry."Alternate UOM" := ItemJournalLine."Alternate UOM";//PRU-VG
        ItemLedgerEntry."Flock No." := ItemJournalLine."Flock No.";//PRU-VG
        ItemLedgerEntry."Item Type" := ItemJournalLine."Item Type";//PRU-VG
        ItemLedgerEntry."Chicks Item" := ItemJournalLine."Chicks Item"; //RK-PRU
        ItemLedgerEntry."Alternate Quantity" := ItemJournalLine."Alternate Quantity";//PRU-VG
        ItemLedgerEntry."Alternate UOM" := ItemJournalLine."Alternate UOM";//PRU-VG
        ItemLedgerEntry."Flock No." := ItemJournalLine."Flock No.";//PRU-VG
        ItemLedgerEntry."Item Type" := ItemJournalLine."Item Type";//PRU-VG
        if ItemJournalLine."Source Type" = ItemJournalLine."Source Type"::Customer then
            if ItemJournalLine."Source No." <> '' then begin
                Cust.get(ItemJournalLine."Source No.");
                ItemLedgerEntry."Salesperson/Purchaser" := Cust."Salesperson Code";

            end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostVendorEntry', '', true, true)]
    local procedure "Purch.-Post_OnBeforePostVendorEntry"
   (
       var GenJnlLine: Record "Gen. Journal Line";
       var PurchHeader: Record "Purchase Header";
       var TotalPurchLine: Record "Purchase Line";
       var TotalPurchLineLCY: Record "Purchase Line";
       PreviewMode: Boolean;
       CommitIsSupressed: Boolean;
       var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"
   )
    begin
        GenJnlLine."Creditors Type" := PurchHeader."Creditors Type"; //PruRaj
        GenJnlLine."Line Narration1" := PurchHeader."Line Narration1";//PRU_NEELESH
        GenJnlLine."User ID" := PurchHeader."SFPL User ID";

    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnAfterPostPurchaseDoc', '', true, true)]
    local procedure "Purch.-Post_OnAfterPostPurchaseDoc"
     (
         var PurchaseHeader: Record "Purchase Header";
         var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
            PurchRcpHdrNo:
                Code[20];
            RetShptHdrNo:
                Code[20];
            PurchInvHdrNo:
                Code[20];
            PurchCrMemoHdrNo:
                Code[20];
            CommitIsSupressed:
                Boolean
     )
    var
        ReturnShipmentHeader11:
            Record "Return Shipment Header";
        PurchRcptHeader11:
                Record "Purch. Rcpt. Header";
        PurchInvHeader11:
                Record "Purch. Inv. Header";
        PurchCrMemoHdr11:
                Record "Purch. Cr. Memo Hdr.";
        PurchRcptHeader1:
                Record "Purch. Rcpt. Header";
        GLEntry: Record "G/L Entry";
        SAlrec: Record "Sales & Receivables Setup";
    begin

        IF PurchCrMemoHdrNo <> '' THEN BEGIN
            SendDebitNoteByEmail(PurchCrMemoHdrNo);
        END;

    end;

    LOCAL procedure SendDebitNoteByEmail(PostedDbNo: Code[20])
    var
        SMTPMail: Codeunit "Email Message";
        ReportPath: Text;
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        Vendor: Record Vendor;
        Outstr: OutStream;
        Instr: InStream;
        TempBlob: Codeunit "Temp Blob";
        RecRef: RecordRef;
        Email: Codeunit Email;
    begin
        PurchCrMemoHdr.Get(PostedDbNo);
        IF Vendor.GET(PurchCrMemoHdr."Buy-from Vendor No.") THEN;
        If Vendor."E-Mail" <> '' Then begin
            SMTPMail.Create(Vendor."E-Mail", 'Debit Note', '', TRUE);
            SMTPMail.AppendToBody('Dear Sir' + ',' + '<BR><BR>');
            SMTPMail.AppendToBody('Please find enclosed herewith the Debit Note for your Record. If you found any discrepancy kindly let us know.' + '.<BR><BR>');
            //SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, 'Purchase@sampoornafeeds.com');
            //SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, 'vishwajeetbehl@sampoornafeeds.in');
            // SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, 'yogesh.chandra@sampoornafeeds.in');
            // SMTPMail.AddRecipient(Enum::"Email Recipient Type"::Cc, ' md.shakib@sampoornafeeds.in');
            PurchCrMemoHdr.RESET;
            PurchCrMemoHdr.SETRANGE(PurchCrMemoHdr."No.", PostedDbNo);
            IF PurchCrMemoHdr.FINDFIRST THEN BEGIN
                RecRef.GetTable(PurchCrMemoHdr);
                TempBlob.CreateOutStream(Outstr);
                Report.SaveAs(Report::"Debit Note", '', ReportFormat::Pdf, Outstr, RecRef);
                TempBlob.CreateInStream(Instr);
                SMTPMail.AddAttachment(PurchCrMemoHdr."No." + '.pdf', 'PDF', Instr);
            END;
            SMTPMail.AppendToBody('With best regards!' + ',' + '<BR>' + 'Sampoorna Feeds Pvt. Ltd.' + '<BR><BR>');
            SMTPMail.AppendToBody('This is system generated mail. Please do not reply.<BR><BR>');
            Email.Send(SMTPMail, Enum::"Email Scenario"::Default);
        end;
    END;

    procedure SetPostandEmailMode(NewPostandSend: Boolean)
    begin
        PostandSend := NewPostandSend;
    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforeInsertReceiptLine', '', true, true)]
    local procedure "Purch.-Post_OnBeforeInsertReceiptLine"
    (
        var PurchRcptHeader: Record "Purch. Rcpt. Header";
        var PurchLine: Record "Purchase Line";
        var CostBaseAmount: Decimal;
        var IsHandled: Boolean

    )
    begin
        IF PurchLine."Document Type" <> PurchLine."Document Type"::Invoice THEN BEGIN //////Pru_gk
            if PurchLine.Type = PurchLine.Type::Item then
                if PurchLine."No." <> '' then
                    IF PurchLine."Excess/Short Qty" > 0 THEN
                        PostItemJnlLineExcessQty(PurchLine);
        END;
        //PRU-FE-004 ->

        IF PurchLine."Document Type" <> PurchLine."Document Type"::Invoice THEN BEGIN ///////////////Pru_gk
            IF PurchRcptHeader."Rate Basis" = PurchRcptHeader."Rate Basis"::EX THEN
                if PurchLine.Type = PurchLine.Type::Item then
                    if PurchLine."No." <> '' then
                        IF PurchLine."Excess/Short Qty" < 0 THEN
                            PostItemJnlLineShortQty(PurchLine, PurchRcptHeader."No.");
            //PRU-FE-004 <-
        END;
    end;

    procedure PostItemJnlLineExcessQty(PurchLine: Record "Purchase Line"): Integer
    var
        ItemJnlLine: Record "Item Journal Line";
        PurchaseHeader: Record "Purchase Header";
        ItemJnlPostLine: Codeunit 22;
    //ik
    begin
        PurchaseHeader.GET(PurchLine."Document Type", PurchLine."Document No.");
        //   WITH PurchLine DO BEGIN
        ItemJnlLine.INIT;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Purchase;
        ItemJnlLine."Posting Date" := PurchaseHeader."Posting Date";
        ItemJnlLine."Document No." := PurchLine."Document No.";
        ItemJnlLine.VALIDATE("Item No.", PurchLine."No.");
        ItemJnlLine."Location Code" := PurchLine."Location Code";
        //ItemJnlLine.Description := PurchLine.Description;
        ItemJnlLine."Unit Amount" := PurchLine."Unit Cost (LCY)";
        ItemJnlLine.VALIDATE(Quantity, PurchLine."Excess/Short Qty");
        ItemJnlLine.VALIDATE("Dimension Set ID", PurchLine."Dimension Set ID"); //PRU-RK5.00
        ItemJnlLine."Alternate Quantity" := PurchLine."Alternate Quantity";
        ItemJnlLine."Alternate UOM" := PurchLine."Alternate UOM";
        ItemJnlLine."Shortcut Dimension 1 Code" := PurchLine."Shortcut Dimension 1 Code";
        ItemJnlLine."Shortcut Dimension 2 Code" := PurchLine."Shortcut Dimension 2 Code";
        ItemJnlLine.VALIDATE("Shortcut Dimension 3 Code", PurchaseHeader."Shortcut Dimension 3 Code"); //Pru_gk
        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
    END;

    procedure PostItemJnlLineShortQty(PurchLine: Record "Purchase Line"; PurRec: Code[20]): Integer
    //PRU-FE-004 ->
    var
        ItemJnlLine: Record "Item Journal Line";
        PurchaseHeader: Record "Purchase Header";
        ItemJnlPostLine: Codeunit 22;
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        PurchaseHeader.GET(PurchLine."Document Type", PurchLine."Document No.");
        ItemJnlLine.INIT;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Purchase;
        ItemJnlLine."Posting Date" := PurchaseHeader."Posting Date";
        ItemJnlLine."Document No." := PurchLine."Document No.";
        ItemJnlLine.VALIDATE("Item No.", PurchLine."No.");
        ItemJnlLine."Location Code" := PurchLine."Location Code";
        ItemJnlLine.VALIDATE(Quantity, PurchLine."Excess/Short Qty");
        ItemJnlLine.VALIDATE("Dimension Set ID", PurchLine."Dimension Set ID"); //PRU-RK5.00
        ItemJnlLine."Alternate Quantity" := PurchLine."Alternate Quantity";
        ItemJnlLine."Alternate UOM" := PurchLine."Alternate UOM";
        ItemJnlLine."Shortcut Dimension 1 Code" := PurchLine."Shortcut Dimension 1 Code";
        ItemJnlLine."Shortcut Dimension 2 Code" := PurchLine."Shortcut Dimension 2 Code";
        ItemJnlLine.VALIDATE("Shortcut Dimension 3 Code", PurchaseHeader."Shortcut Dimension 3 Code"); //Pru_gk
        ItemLedgerEntry.RESET;
        ItemLedgerEntry.SETRANGE(ItemLedgerEntry."Document Type", ItemLedgerEntry."Document Type"::"Purchase Receipt");
        ItemLedgerEntry.SETRANGE(ItemLedgerEntry."Document No.", PurRec);
        IF ItemLedgerEntry.FINDLAST THEN BEGIN
            //MESSAGE('%1',ItemLedgerEntry."Entry No.");
            ItemJnlLine.VALIDATE(ItemJnlLine."Applies-to Entry", ItemLedgerEntry."Entry No.");
        END;
        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
    END;
    //PRU-FE-004 <-

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Purch.-Post", 'OnBeforePostPurchaseDoc', '', true, true)]
    local procedure "Purch.-Post_OnBeforePostPurchaseDoc"

        (
            var PurchaseHeader: Record "Purchase Header";
            PreviewMode: Boolean;
            CommitIsSupressed: Boolean;
            var HideProgressWindow: Boolean;
            var ItemJnlPostLine: Codeunit 22
        )
    var
        SALPri: Record "Sales Price";
        DimensionMaster: Record 50030;
        PurchaseLine_123: Record 39;
        DimensionSetEntry_123: Record 480;
        Vendor: Record 23;
        PurchLine: Record 39;
        Item: Record 27;
        Text50000: Label 'Please select the TDS Section of deduction for Line No. %1';
        Text50001: Label 'TDS Section of deduction must be blank in Line No. %1';
        UserSetup: Record "User Setup";
        PurchSetup1: Record "Responsibility Center";
        Location: record location;
        PurchSetup: Record "Purchases & Payables Setup";
        DOCAtt: Record "Document Attachment";
        InvoiceCheck: Boolean;
        PurrecH: Record "Purch. Rcpt. Header";
        LocationRec: Record Location;
        Customer: Record Vendor;
        SLRec1: Record "Purchase Line";
        SLRec2: Record "Purchase Line";
        SLRec: Record "Purchase Line";
        GSTSetup1: Record "GST Setup";
        //TaxComponentName1: Record "Tax Component";
        TaxTransactionValue: Record "Tax Transaction Value";
        TaxComponentName1: Text;
        DGL: Record "Detailed GST Ledger Entry";
        FALedger: Record "FA Ledger Entry";
        CompanyInfo: Record "Company Information";
        VendorPost: Record "Vendor Posting Group";
        RecItem: Record Item;
        RecFA: Record "Fixed Asset";
        TimeChecking: Boolean;
        Time1: Time;
        TDSSetup1: Record "TDS Setup";
        StarPL: Record "Purchase Line";
    begin
        CompanyInfo.Get;
        VendorPost.Get(PurchaseHeader."Vendor Posting Group");
        Time1 := Time;
        TimeChecking := False;

        // if PurchaseHeader.Status = PurchaseHeader.Status::Expired then
        //     Error('You can not post the Expired Purchase Order, Please contact to Purchaser');

        If PurchaseHeader."Document Type" in [PurchaseHeader."Document Type"::Order] Then
            If (PurchaseHeader.Receive = true) Then
                If (PurchaseHeader."PO Type" = PurchaseHeader."PO Type"::Goods) Then
                    If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
                        UserSetup.Reset();
                        UserSetup.SetRange(UserSetup."User ID", UserId);
                        UserSetup.SetRange("Tax Details Permission", True);
                        if not UserSetup.FindFirst() then
                            If PurchaseHeader."Posting Date" <> Today then Begin
                                if (Format(Time1) >= '08:00:00.000') and (Format(Time1) <= '12:30:00.000') Then
                                    TimeChecking := True;

                                if not TimeChecking Then
                                    Error('You can not post the Entry in back date, Current Date and Time in %1', CurrentDateTime);
                            end;

                        if PurchaseHeader."PO Expiration Date" <= (WorkDate() - 1) then begin
                            PurchLine.Reset();
                            PurchLine.SetRange("Document Type", PurchLine."Document Type"::Order);
                            PurchLine.SetRange("Document No.", PurchaseHeader."No.");
                            PurchLine.SetRange("Item Category Code", 'RM');
                            if PurchLine.FindFirst() Then begin
                                Error('PO Should not be expired, the Expiration Date on PO is %1, Contact with Purchaser', PurchaseHeader."PO Expiration Date");
                            end;
                        end;
                    end;

        SLRec.Reset();
        SLRec.SetRange("Document No.", PurchaseHeader."No.");
        SLRec.SetFilter("No.", '<>%1', '');
        SLRec.SetFilter("GST Group Code", '<>%1', '');
        if SLRec.FindFirst() then
            repeat
                Customer.get(SLRec."Buy-from Vendor No.");
                LocationRec.get(SLRec."Location Code");
                if SLRec."Location Code" <> PurchaseHeader."Location Code" then
                    Error('Line Location Code does not match from header Location on Line No. %1', SLRec."Line No.");

            until SLRec.Next() = 0;


        PurchLine.Reset();
        PurchLine.SetRange("Document No.", PurchaseHeader."No.");
        PurchLine.SetRange(Type, PurchLine.Type::"Fixed Asset");
        PurchLine.SetFilter("No.", '<>%1', '');
        PurchLine.SetRange("FA Posting Type", PurchLine."FA Posting Type"::"Acquisition Cost");
        PurchLine.SetFilter("Qty. to Invoice", '<>%1', 0);
        if PurchLine.FindSet() then
            repeat
                FALedger.Reset();
                FALedger.SetRange("FA No.", PurchLine."No.");
                FALedger.SetRange("FA Posting Type", FALedger."FA Posting Type"::Depreciation);
                if FALedger.FindFirst() then
                    Error('You can not post the Accusition cost beacuse it is already Acquired the FA No., %1', PurchLine."No.")

            UNTIL PurchLine.NEXT = 0;


        InvoiceCheck := false;
        if (PurchaseHeader.Receive = false) AND (PurchaseHeader.Invoice = false) then
            InvoiceCheck := true;
        If CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna then Begin
            DimensionMaster.RESET;
            DimensionMaster.SETRANGE("Shortcut Dimension 1 Code", PurchaseHeader."Shortcut Dimension 1 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 2 Code", PurchaseHeader."Shortcut Dimension 2 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 3 Code", PurchaseHeader."Shortcut Dimension 3 Code");
            IF NOT DimensionMaster.FINDFIRST THEN
                ERROR('Dimension Master Does not exist');
        end;

        If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] Then begin
            StarPL.Reset();
            StarPL.SetRange("Document Type", PurchaseHeader."Document Type");
            StarPL.SetRange("Document No.", PurchaseHeader."No.");
            StarPL.SetRange(Type, StarPL.Type::Item);
            StarPL.SetRange("Item Type", StarPL."Item Type"::Bird);
            if StarPL.FindSet() then
                repeat
                    if (StarPL."Qty. to Invoice" <> 0) or (StarPL."Qty. to Receive" <> 0) then
                        If StarPL."Alternate Quantity" = 0 then
                            Error('Please Update the Alternate Qty of Item No. %1 and Line No. %2', StarPL."No.", StarPL."Line No.");
                until StarPL.Next() = 0;
        end;

        IF PurchaseHeader.Invoice OR InvoiceCheck THEN BEGIN
            IF PurchaseHeader.Invoice OR InvoiceCheck THEN BEGIN
                Vendor.RESET;
                IF Vendor.GET(PurchaseHeader."Buy-from Vendor No.") THEN BEGIN
                    IF Vendor."TDS 194Q" THEN BEGIN
                        PurchLine.RESET;
                        PurchLine.SETRANGE(PurchLine."Document No.", PurchaseHeader."No.");
                        PurchLine.SETFILTER("Document Type", '%1|%2|%3|%4', PurchLine."Document Type"::Order, PurchLine."Document Type"::Invoice, PurchLine."Document Type"::"Credit Memo", PurchLine."Document Type"::"Return Order");
                        PurchLine.SETFILTER(PurchLine.Type, '%1', PurchLine.Type::Item);
                        IF PurchLine.FINDSET THEN BEGIN
                            REPEAT
                                RecItem.Get(PurchLine."No.");
                                if RecItem.Type = RecItem.Type::Inventory Then
                                    IF PurchLine."TDS Section Code" = '' THEN
                                        ERROR(Text50000, PurchLine."Line No.");
                            UNTIL PurchLine.NEXT = 0;

                        END;
                    END ELSE BEGIN
                        PurchLine.RESET;
                        PurchLine.SETRANGE(PurchLine."Document No.", PurchaseHeader."No.");
                        PurchLine.SETFILTER(PurchLine.Type, '%1', PurchLine.Type::Item);
                        IF PurchLine.FINDSET THEN BEGIN
                            REPEAT
                                RecItem.Get(PurchLine."No.");
                                if RecItem.Type = RecItem.Type::Inventory Then
                                    IF PurchLine."TDS Section Code" <> '' THEN
                                        ERROR(Text50001, PurchLine."Line No.");
                            UNTIL PurchLine.NEXT = 0;
                        END;
                    END;
                END;
            END;
        END;
        //If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] Then
        IF PurchaseHeader.Invoice OR InvoiceCheck THEN BEGIN
            PurchLine.RESET;
            PurchLine.SETRANGE("Document No.", PurchaseHeader."No.");
            PurchLine.SETRANGE(Type, PurchLine.Type::Item);
            PurchLine.SETfilter("Document Type", '%1|%2', PurchLine."Document Type"::Order, PurchLine."Document Type"::Invoice);
            PurchLine.SETFILTER("No.", '<>%1', VendorPost."Invoice Rounding Account");
            IF PurchLine.FINDSET THEN BEGIN
                REPEAT
                    Item.RESET;
                    Item.SETRANGE("No.", PurchLine."No.");
                    IF Item.FINDFIRST THEN BEGIN
                        IF Item."Inventory Posting Group" <> 'RM' THEN begin
                            //PurchaseHeader.TESTFIELD("Incoming Document Entry No.");
                            DOCAtt.Reset();
                            DOCAtt.SetRange("No.", PurchaseHeader."No.");
                            if not DOCAtt.FindFirst() then
                                Error('Please attached the document');
                        end;
                    END;
                UNTIL PurchLine.NEXT = 0;
            END ELSE BEGIN
                PurchLine.RESET;
                PurchLine.SETRANGE("Document No.", PurchaseHeader."No.");
                PurchLine.SETFILTER(Type, '<>%1|%2', PurchLine.Type::"Charge (Item)", PurchLine.Type::" ");
                PurchLine.SETfilter("Document Type", '%1|%2', PurchLine."Document Type"::Order, PurchLine."Document Type"::Invoice);
                PurchLine.SETFILTER("No.", '<>%1', VendorPost."Invoice Rounding Account");
                IF PurchLine.FINDSET THEN begin
                    DOCAtt.Reset();
                    DOCAtt.SetRange("No.", PurchaseHeader."No.");
                    if not DOCAtt.FindFirst() then
                        Error('Please attached the document');
                end;
                //PurchaseHeader.TESTFIELD("Incoming Document Entry No.");
            END;
        END;
        // Suman 14-03-2024
        IF PurchaseHeader.Invoice OR InvoiceCheck THEN BEGIN
            PurchLine.Reset();
            PurchLine.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchLine.SetRange("Document No.", PurchaseHeader."No.");
            if PurchLine.FindFirst() then
                repeat
                    if PurchLine.Type <> PurchLine.Type::" " then begin
                        if PurchLine."No." <> VendorPost."Invoice Rounding Account" then begin
                            if PurchLine."GST Group Code" = '' then
                                Error('Please update the GST Group Code');
                            if PurchLine."HSN/SAC Code" = '' then
                                Error('Please update the HSN/SAC Code');
                            if PurchLine."GST Credit" = PurchLine."GST Credit"::" " then
                                Error('Please update the GST Credit Field');
                        end;

                    end;
                Until PurchLine.Next() = 0;
        end;
        If PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then begin
            if (PurchaseHeader."Shortcut Dimension 1 Code" = 'FEED') Then
                PurchaseHeader.TestField("Applies-to ID");
            if (PurchaseHeader."Shortcut Dimension 1 Code" = 'CATTLE') Then
                PurchaseHeader.TestField("Applies-to ID");

        end;
        IF PurchaseHeader.Invoice OR InvoiceCheck THEN begin
            if PurchaseHeader."GST Vendor Type" = PurchaseHeader."GST Vendor Type"::Unregistered Then begin
                PurchLine.Reset();
                PurchLine.SetRange("Document No.", PurchaseHeader."No.");
                if PurchLine."GST Reverse Charge" then
                    IF PurchaseHeader."Invoice Type" <> PurchaseHeader."Invoice Type"::"Self Invoice" then
                        Error('Please Select the Invoice Type as Self Invoice because the Invoice under Reverse charge with Unregistered Vendor');
            end;
        end;

        IF PurchaseHeader.Invoice OR InvoiceCheck THEN begin
            if CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] Then begin
                PurchLine.Reset();
                PurchLine.SetRange("Document No.", PurchaseHeader."No.");
                PurchLine.SetRange(Type, PurchLine.Type::"Fixed Asset");
                PurchLine.SetRange("FA Posting Type", PurchLine."FA Posting Type"::"Acquisition Cost");
                PurchLine.SetFilter("Posting Group", '<>%1', 'LAND');
                if PurchLine.FindSet() then
                    repeat
                        if (PurchLine."Qty. to Invoice" <> 0) and (PurchLine."Document Type" = PurchLine."Document Type"::Order) then begin
                            if PurchLine."Salvage Value" = 0 then begin
                                RecFA.Get(PurchLine."No.");
                                if (RecFA."WIP Assets" = false) and (RecFA."FA Class Code" = 'TANGIBLE') Then
                                    Error('Update the Salvage value');
                            end;
                        end else
                            if (PurchLine.Quantity <> 0) and (PurchLine."Document Type" = PurchLine."Document Type"::Invoice) then begin
                                if PurchLine."Salvage Value" = 0 then begin
                                    RecFA.Get(PurchLine."No.");
                                    if (RecFA."WIP Assets" = false) and (RecFA."FA Class Code" = 'TANGIBLE') Then
                                        Error('Update the Salvage value');
                                end;
                            end;
                    until PurchLine.Next = 0;
            end;
        end;

        IF PurchaseHeader.Invoice OR InvoiceCheck THEN BEGIN
            PurchLine.Reset();
            PurchLine.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchLine.SetRange("Document No.", PurchaseHeader."No.");
            PurchLine.SetFilter("Qty. to Invoice", '<>%1', 0);
            PurchLine.SetFilter("GST Group Code", '<>%1', '');
            PurchLine.SetFilter("HSN/SAC Code", '<>%1', '');
            PurchLine.SetFilter("GST Credit", '<>%1', PurchLine."GST Credit"::" ");
            if PurchLine.FindFirst() then
                repeat
                    GSTSetup1.Get;
                    TaxTransactionValue.Reset();
                    TaxTransactionValue.SetRange("Tax Type", GSTSetup1."GST Tax Type");
                    TaxTransactionValue.SetRange("Tax Record ID", PurchLine.RecordId());
                    TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
                    //TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                    if TaxTransactionValue.IsEmpty then
                        Error('GST Must be Calculated');
                Until PurchLine.Next() = 0;

            PurchLine.Reset();
            PurchLine.SetRange("Document Type", PurchaseHeader."Document Type");
            PurchLine.SetRange("Document No.", PurchaseHeader."No.");
            PurchLine.SetFilter("Qty. to Invoice", '<>%1', 0);
            PurchLine.SetFilter("TDS Section Code", '<>%1', '');
            if PurchLine.FindFirst() then
                repeat
                    TDSSetup1.Get;
                    TaxTransactionValue.Reset();
                    TaxTransactionValue.SetRange("Tax Type", TDSSetup1."Tax Type");
                    TaxTransactionValue.SetRange("Tax Record ID", PurchLine.RecordId());
                    TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
                    //TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                    if TaxTransactionValue.IsEmpty then
                        Error('TDS Must be Calculated');
                Until PurchLine.Next() = 0;
        end;
        // if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna Then
        //     if (PurchaseHeader."Shortcut Dimension 1 Code" = 'FEED') and (PurchaseHeader."Shortcut Dimension 1 Code" = 'CATTLE') then
        //         if PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::"Credit Memo" then
        //             IF PurchaseHeader.Invoice OR InvoiceCheck THEN
        //                 if PurchaseHeader."Brokerage Rate"=0 then


        IF PurchaseHeader.Invoice OR InvoiceCheck THEN
            CheckAppliedEntry(PurchaseHeader);

    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Undo Purchase Receipt Line", 'OnBeforeCheckPurchRcptLine', '', False, False)]
    procedure UndoApplication(var PurchRcptLine: Record "Purch. Rcpt. Line"; var IsHandled: Boolean; var TempItemLedgerEntry: Record "Item Ledger Entry" temporary);
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ItemApplicationEntry: Record "Item Application Entry";
        ReturnedInvoicedItemLedgerEntry: Record "Item Ledger Entry";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        PostEntryNo: Record 32;
        TempUnapplyItem: Record Item temporary;
        PurchaseReceiptHeader: Record "Purch. Rcpt. Header";
    begin

        // PurchRcptLine.get(PurchaseReceiptHeader."No.");
        PurchaseReceiptHeader.Get(PurchRcptLine."Document No.");

        if PurchRcptLine.Type = PurchRcptLine.Type::Item then begin
            if PurchRcptLine."Quantity Invoiced" <> 0 then
                exit;
            if PurchRcptLine."Excess Qty" < 0 then begin
                If PurchaseReceiptHeader."Rate Basis" <> PurchaseReceiptHeader."Rate Basis"::EX Then
                    exit;
                PostEntryNo := PostItemJnlLineUndoExcessQty(PurchRcptLine);
                ItemLedgerEntry.SetRange("Document Type", ItemLedgerEntry."Document Type"::"Purchase Receipt");
                ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::"Purchase");
                ItemLedgerEntry.SetRange("Document No.", PurchRcptLine."Document No.");
                ItemLedgerEntry.SetRange("Document Line No.", PurchRcptLine."Line No.");
                ItemLedgerEntry.SetLoadFields("Invoiced Quantity", "Entry No.");
                ItemLedgerEntry.FindSet();
                repeat
                    if ItemApplicationEntry.AppliedOutbndEntryExists(ItemLedgerEntry."Entry No.", false, false) then
                        repeat
                            if ItemApplicationEntry."Item Ledger Entry No." = ItemApplicationEntry."Outbound Item Entry No." then begin
                                ReturnedInvoicedItemLedgerEntry.Get(ItemApplicationEntry."Item Ledger Entry No.");
                                ItemJnlPostLine.SetCalledFromApplicationWorksheet(true);
                                ItemJnlPostLine.RestoreTouchedEntries(TempUnapplyItem);

                                if ItemJnlPostLine.AnyTouchedEntries() then begin
                                    UnblockItems(ItemLedgerEntry."Item No.");
                                    ItemJnlPostLine.RedoApplications();
                                    ItemJnlPostLine.CostAdjust();
                                    ItemJnlPostLine.ClearApplicationLog();
                                end;

                                ItemJnlPostLine.UnApply(ItemApplicationEntry);
                                ItemJnlPostLine.LogUnapply(ItemApplicationEntry);
                                BlockItem(ItemLedgerEntry."Item No.");

                                ReturnedInvoicedItemLedgerEntry.Get(ItemApplicationEntry."Item Ledger Entry No.");
                                if PostEntryNo."Entry No." <> 0 then begin
                                    ItemJnlPostLine.ReApply(PostEntryNo, ReturnedInvoicedItemLedgerEntry."Entry No.");
                                    ItemJnlPostLine.LogApply(PostEntryNo, ReturnedInvoicedItemLedgerEntry);
                                    if PostEntryNo.Positive then
                                        RemoveDuplicateApplication(PostEntryNo."Entry No.");
                                end;

                                if ItemJnlPostLine.AnyTouchedEntries() then begin
                                    UnblockItems(ItemLedgerEntry."Item No.");
                                    ItemJnlPostLine.RedoApplications();
                                    ItemJnlPostLine.CostAdjust();
                                    ItemJnlPostLine.ClearApplicationLog();
                                end;
                            end;
                        until ItemApplicationEntry.Next() = 0;
                until ItemLedgerEntry.Next() = 0;
            end else
                if PurchRcptLine."Excess Qty" > 0 then begin
                    PostItemJnlLineUndoShortQty(PurchRcptLine);
                end;
        End;
    end;
    //End;

    //UndoQty > 0
    procedure PostItemJnlLineUndoExcessQty(PurchLine: Record "Purch. Rcpt. Line"): Record 32;
    var
        ItemJnlLine: Record "Item Journal Line";
        PurchaseHeader: Record "Purch. Rcpt. Header";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        ItemLedgerEntry: Record 32;


    begin
        PurchaseHeader.GET(PurchLine."Document No.");

        ItemJnlLine.INIT;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Purchase;
        ItemJnlLine."Posting Date" := PurchaseHeader."Posting Date";
        ItemJnlLine."Document No." := PurchaseHeader."Order No.";
        ItemJnlLine.VALIDATE("Item No.", PurchLine."No.");
        ItemJnlLine."Location Code" := PurchLine."Location Code";
        ItemJnlLine."Unit Amount" := PurchLine."Unit Cost (LCY)";
        ItemJnlLine.VALIDATE(Quantity, PurchLine."Excess Qty" * -1);
        ItemJnlLine.VALIDATE("Dimension Set ID", PurchLine."Dimension Set ID");
        ItemJnlLine."Alternate Quantity" := PurchLine."Alternate Quantity";
        ItemJnlLine."Alternate UOM" := PurchLine."Alternate UOM";
        ItemJnlLine."Shortcut Dimension 1 Code" := PurchLine."Shortcut Dimension 1 Code";
        ItemJnlLine."Shortcut Dimension 2 Code" := PurchLine."Shortcut Dimension 2 Code";
        ItemJnlLine.VALIDATE("Shortcut Dimension 3 Code", PurchaseHeader."Shortcut Dimension 3 Code");
        ItemJnlPostLine.RunWithCheck(ItemJnlLine);

        ItemLedgerEntry.RESET;
        ItemLedgerEntry.SetCurrentKey("Entry No.");
        ItemLedgerEntry.SETRANGE(ItemLedgerEntry."Document No.", PurchaseHeader."Order No.");
        ItemLedgerEntry.SetRange("Item No.", PurchLine."No.");
        ItemLedgerEntry.SetRange(Quantity, PurchLine."Excess Qty" * -1);
        IF ItemLedgerEntry.FINDLAST THEN
            exit(ItemLedgerEntry);
    END;

    //UndoQty < 0
    procedure PostItemJnlLineUndoShortQty(PurchLine: Record "Purch. Rcpt. Line")
    var
        ItemJnlLine: Record "Item Journal Line";
        PurchaseHeader: Record "Purch. Rcpt. Header";
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        PurchaseHeader.GET(PurchLine."Document No.");
        ItemJnlLine.INIT;
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Purchase;
        ItemJnlLine."Posting Date" := PurchaseHeader."Posting Date";
        ItemJnlLine."Document No." := PurchaseHeader."Order No.";
        ItemJnlLine.VALIDATE("Item No.", PurchLine."No.");
        ItemJnlLine."Location Code" := PurchLine."Location Code";
        ItemJnlLine.VALIDATE(Quantity, PurchLine."Excess Qty" * -1);
        ItemJnlLine.VALIDATE("Dimension Set ID", PurchLine."Dimension Set ID");
        ItemJnlLine."Alternate Quantity" := PurchLine."Alternate Quantity";
        ItemJnlLine."Alternate UOM" := PurchLine."Alternate UOM";
        ItemJnlLine."Shortcut Dimension 1 Code" := PurchLine."Shortcut Dimension 1 Code";
        ItemJnlLine."Shortcut Dimension 2 Code" := PurchLine."Shortcut Dimension 2 Code";
        ItemJnlLine.VALIDATE("Shortcut Dimension 3 Code", PurchaseHeader."Shortcut Dimension 3 Code");

        ItemLedgerEntry.RESET;
        ItemLedgerEntry.SetCurrentKey("Entry No.");
        ItemLedgerEntry.SETRANGE(ItemLedgerEntry."Document No.", PurchaseHeader."Order No.");
        ItemLedgerEntry.SetRange("Item No.", PurchLine."No.");
        ItemLedgerEntry.SetRange(Quantity, PurchLine."Excess Qty");
        ItemLedgerEntry.SetRange("Posting Date", PurchaseHeader."Posting Date");
        IF ItemLedgerEntry.FINDLAST then
            ItemJnlLine.VALIDATE(ItemJnlLine."Applies-to Entry", ItemLedgerEntry."Entry No.");

        ItemJnlPostLine.RunWithCheck(ItemJnlLine);
    END;

    procedure BlockItem(ItemNo: Code[20])
    var
        Item: Record Item;
    begin

        Item.Get(ItemNo);
        if Item."Application Wksh. User ID" <> UpperCase(UserId) then
            Item.CheckBlockedByApplWorksheet();

        Item."Application Wksh. User ID" := UserId;
        Item.Modify(true);
    end;

    procedure UnblockItems(ItemNo: Code[20])
    var
        Item: Record Item;
    begin
        Item.Get(ItemNo);
        if Item."Application Wksh. User ID" = UpperCase(UserId) then begin
            Item."Application Wksh. User ID" := '';
            Item.Modify();
        end;

    end;

    procedure RemoveDuplicateApplication(ItemLedgerEntryNo: Integer)
    var
        ItemApplicationEntry: Record "Item Application Entry";

    begin
        with ItemApplicationEntry do begin
            SetCurrentKey("Inbound Item Entry No.", "Item Ledger Entry No.", "Outbound Item Entry No.", "Cost Application");
            SetRange("Inbound Item Entry No.", ItemLedgerEntryNo);
            SetRange("Item Ledger Entry No.", ItemLedgerEntryNo);
            SetFilter("Outbound Item Entry No.", '<>0');
            if not IsEmpty() then begin
                SetRange("Outbound Item Entry No.", 0);
                DeleteAll();
            end
        end;
    end;

    LOcal procedure CheckAppliedEntry(PurchaseHeader121: Record "Purchase Header")
    var
        VendorLedgerEntry: Record "Vendor Ledger Entry";
        IsApplied: Boolean;
        PurchaseLine: Record "Purchase Line";
        PurchRcptHeader1: Record "Purch. Rcpt. Header";
    begin
        IsApplied := FALSE;
        IF PurchaseHeader121."Document Type" = PurchaseHeader121."Document Type"::Order THEN BEGIN
            VendorLedgerEntry.RESET;
            VendorLedgerEntry.SETRANGE(VendorLedgerEntry.Open, TRUE);
            VendorLedgerEntry.SETRANGE(VendorLedgerEntry."Vendor No.", PurchaseHeader121."Pay-to Vendor No.");
            VendorLedgerEntry.SETRANGE(VendorLedgerEntry."Applied PO No.", PurchaseHeader121."No.");
            VendorLedgerEntry.CALCFIELDS(VendorLedgerEntry."Remaining Amount");
            VendorLedgerEntry.SETFILTER(VendorLedgerEntry."Remaining Amount", '<>%1', 0);
            IF VendorLedgerEntry.FINDSET THEN
                REPEAT
                    IF (VendorLedgerEntry."Applies-to ID" = '') THEN
                        IsApplied := TRUE;
                UNTIL VendorLedgerEntry.NEXT = 0;
        END ELSE
            IF PurchaseHeader121."Document Type" = PurchaseHeader121."Document Type"::Invoice THEN BEGIN
                PurchaseLine.RESET;
                PurchaseLine.SETRANGE(PurchaseLine."Document No.", PurchaseHeader121."No.");
                PurchaseLine.SETFILTER(PurchaseLine.Type, '<>%1', PurchaseLine.Type::" ");
                IF PurchaseLine.FINDFIRST THEN BEGIN
                    PurchRcptHeader1.RESET;
                    PurchRcptHeader1.SETRANGE(PurchRcptHeader1."No.", PurchaseLine."Receipt No.");
                    IF PurchRcptHeader1.FINDFIRST THEN BEGIN
                        VendorLedgerEntry.RESET;
                        VendorLedgerEntry.SETRANGE(VendorLedgerEntry.Open, TRUE);
                        VendorLedgerEntry.SETRANGE(VendorLedgerEntry."Vendor No.", PurchaseHeader121."Buy-from Vendor No.");
                        VendorLedgerEntry.SETRANGE(VendorLedgerEntry."Applied PO No.", PurchRcptHeader1."Order No.");
                        VendorLedgerEntry.CALCFIELDS(VendorLedgerEntry."Remaining Amount");
                        VendorLedgerEntry.SETFILTER(VendorLedgerEntry."Remaining Amount", '<>%1', 0);
                        IF VendorLedgerEntry.FINDSET THEN
                            REPEAT
                                IF (VendorLedgerEntry."Applies-to ID" = '') THEN
                                    IsApplied := TRUE;
                            UNTIL VendorLedgerEntry.NEXT = 0;
                    END;
                END;
            END;

        IF IsApplied THEN
            ERROR('Please Apply Purchase Document with Advance Payment');

    end;

    procedure UndoReceipt(RecPurchRcptLine: Record "Purch. Rcpt. Line")
    var
        PostedWhseRcptLine: Record "Posted Whse. Receipt Line";
        PurchLine: Record "Purchase Line";
        Window: Dialog;
        ItemRcptEntryNo: Integer;
        DocLineNo: Integer;
        PostedWhseRcptLineFound: Boolean;
        PurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        //OnBeforeCode(PurchRcptLine, UndoPostingMgt);
        PurchRcptLine.reset();
        PurchRcptLine.SetRange("Document No.", RecPurchRcptLine."Document No.");
        PurchRcptLine.SetRange("Line No.", RecPurchRcptLine."Line No.");
        if PurchRcptLine.FindFirst() then;
        with PurchRcptLine do begin
            CheckPurchRcptLines(PurchRcptLine, Window);

            Find('-');
            repeat
                TempGlobalItemLedgEntry.Reset();
                if not TempGlobalItemLedgEntry.IsEmpty() then
                    TempGlobalItemLedgEntry.DeleteAll();
                TempGlobalItemEntryRelation.Reset();
                if not TempGlobalItemEntryRelation.IsEmpty() then
                    TempGlobalItemEntryRelation.DeleteAll();

                // if not HideDialog then
                //     Window.Open(Text001);

                if Type = Type::Item then begin
                    PostedWhseRcptLineFound :=
                    WhseUndoQty.FindPostedWhseRcptLine(
                        PostedWhseRcptLine,
                        DATABASE::"Purch. Rcpt. Line",
                        "Document No.",
                        DATABASE::"Purchase Line",
                        PurchLine."Document Type"::Order.AsInteger(),
                        "Order No.",
                        "Order Line No.");

                    ItemRcptEntryNo := PostItemJnlLine(PurchRcptLine, DocLineNo);
                end else
                    DocLineNo := GetCorrectionLineNo(PurchRcptLine);

                InsertNewReceiptLine(PurchRcptLine, ItemRcptEntryNo, DocLineNo);
                //OnAfterInsertNewReceiptLine(PurchRcptLine, PostedWhseRcptLine, PostedWhseRcptLineFound, DocLineNo, PostedWhseRcptLine);

                if PostedWhseRcptLineFound then
                    WhseUndoQty.UndoPostedWhseRcptLine(PostedWhseRcptLine);

                UndoPurchreceiptLine.UpdateOrderLine(PurchRcptLine);
                if PostedWhseRcptLineFound then
                    WhseUndoQty.UpdateRcptSourceDocLines(PostedWhseRcptLine);

                if ("Blanket Order No." <> '') and ("Blanket Order Line No." <> 0) then
                    UndoPurchreceiptLine.UpdateBlanketOrder(PurchRcptLine);

                "Quantity Invoiced" := Quantity;
                "Qty. Invoiced (Base)" := "Quantity (Base)";
                "Qty. Rcd. Not Invoiced" := 0;
                Correction := true;

                //OnBeforePurchRcptLineModify(PurchRcptLine, TempWhseJnlLine);
                Modify();
            //OnAfterPurchRcptLineModify(PurchRcptLine, TempWhseJnlLine, DocLineNo, UndoPostingMgt);

            // if not JobItem then
            //     JobItem := (Type = Type::Item) and ("Job No." <> '');
            until Next() = 0;

            MakeInventoryAdjustment();

            WhseUndoQty.PostTempWhseJnlLine(TempWhseJnlLine);
        end;

        //OnAfterCode(PurchRcptLine, UndoPostingMgt);
    end;

    local procedure InsertNewReceiptLine(OldPurchRcptLine: Record "Purch. Rcpt. Line"; ItemRcptEntryNo: Integer; DocLineNo: Integer)
    var
        NewPurchRcptLine: Record "Purch. Rcpt. Line";
    begin
        with OldPurchRcptLine do begin
            NewPurchRcptLine.Init();
            NewPurchRcptLine.Copy(OldPurchRcptLine);
            NewPurchRcptLine."Line No." := DocLineNo;
            NewPurchRcptLine."Appl.-to Item Entry" := "Item Rcpt. Entry No.";
            NewPurchRcptLine."Item Rcpt. Entry No." := ItemRcptEntryNo;
            NewPurchRcptLine.Quantity := -Quantity;
            NewPurchRcptLine."Quantity (Base)" := -"Quantity (Base)";
            NewPurchRcptLine."Quantity Invoiced" := NewPurchRcptLine.Quantity;
            NewPurchRcptLine."Qty. Invoiced (Base)" := NewPurchRcptLine."Quantity (Base)";
            NewPurchRcptLine."Qty. Rcd. Not Invoiced" := 0;
            NewPurchRcptLine.Correction := true;
            NewPurchRcptLine."Dimension Set ID" := "Dimension Set ID";
            //OnBeforeNewPurchRcptLineInsert(NewPurchRcptLine, OldPurchRcptLine);
            NewPurchRcptLine.Insert();
            //OnAfterNewPurchRcptLineInsert(NewPurchRcptLine, OldPurchRcptLine);

            InsertItemEntryRelation(TempGlobalItemEntryRelation, NewPurchRcptLine);
        end;
    end;

    local procedure InsertItemEntryRelation(var TempItemEntryRelation: Record "Item Entry Relation" temporary; NewPurchRcptLine: Record "Purch. Rcpt. Line")
    var
        ItemEntryRelation: Record "Item Entry Relation";
    begin
        if TempItemEntryRelation.Find('-') then
            repeat
                ItemEntryRelation := TempItemEntryRelation;
                ItemEntryRelation.TransferFieldsPurchRcptLine(NewPurchRcptLine);
                ItemEntryRelation.Insert();
            until TempItemEntryRelation.Next() = 0;
    end;

    local procedure MakeInventoryAdjustment()
    var
        InvtSetup: Record "Inventory Setup";
        InvtAdjmtHandler: Codeunit "Inventory Adjustment Handler";
    begin
        InvtSetup.Get();
        if InvtSetup.AutomaticCostAdjmtRequired() then begin
            //InvtAdjmtHandler.SetJobUpdateProperties(not JobItem);
            InvtAdjmtHandler.MakeInventoryAdjustment(true, InvtSetup."Automatic Cost Posting");
        end;
    end;

    local procedure CheckPurchRcptLines(var PurchRcptLine: Record "Purch. Rcpt. Line"; var Window: Dialog)
    var
        IsHandled: Boolean;
    begin
        // IsHandled := false;
        // OnBeforeCheckPurchRcptLines(PurchRcptLine, Window, IsHandled);
        // if IsHandled then
        //     exit;

        with PurchRcptLine do begin
            SetFilter(Quantity, '<>0');
            SetRange(Correction, false);
            // OnCheckPurchRcptLinesAfterPurchRcptLineSetFilters(PurchRcptLine);
            if IsEmpty() then
                Error(AllLinesCorrectedErr);

            FindFirst();
            repeat
                // if not HideDialog then
                //     Window.Open(Text003);
                CheckPurchRcptLine(PurchRcptLine);
            until Next() = 0;
        end;
    end;

    local procedure CheckPurchRcptLine(PurchRcptLine: Record "Purch. Rcpt. Line")
    var
        TempItemLedgEntry: Record "Item Ledger Entry" temporary;
        IsHandled: Boolean;
    begin
        // IsHandled := false;
        // OnBeforeCheckPurchRcptLine(PurchRcptLine, IsHandled, TempItemLedgEntry);
        // if IsHandled then
        //     exit;

        with PurchRcptLine do begin
            if Correction then
                Error(AlreadyReversedErr);
            if "Qty. Rcd. Not Invoiced" <> Quantity then
                if HasInvoicedNotReturnedQuantity(PurchRcptLine) then
                    Error(Text004);
            if Type = Type::Item then begin
                TestField("Prod. Order No.", '');
                TestField("Sales Order No.", '');
                TestField("Sales Order Line No.", 0);

                UndoPostingMgt.TestPurchRcptLine(PurchRcptLine);
                UndoPostingMgt.CollectItemLedgEntries(TempItemLedgEntry, DATABASE::"Purch. Rcpt. Line",
                  "Document No.", "Line No.", "Quantity (Base)", "Item Rcpt. Entry No.");
                UndoPostingMgt.CheckItemLedgEntries(TempItemLedgEntry, "Line No.", "Qty. Rcd. Not Invoiced" <> Quantity);
            end;
        end;
    end;

    local procedure HasInvoicedNotReturnedQuantity(PurchRcptLine: Record "Purch. Rcpt. Line"): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReturnedInvoicedItemLedgerEntry: Record "Item Ledger Entry";
        ItemApplicationEntry: Record "Item Application Entry";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchInvLine: Record "Purch. Inv. Line";
        InvoicedQuantity: Decimal;
        ReturnedInvoicedQuantity: Decimal;
    begin
        if PurchRcptLine.Type = PurchRcptLine.Type::Item then begin
            ItemLedgerEntry.SetRange("Document Type", ItemLedgerEntry."Document Type"::"Purchase Receipt");
            ItemLedgerEntry.SetRange("Entry Type", ItemLedgerEntry."Entry Type"::"Purchase");
            ItemLedgerEntry.SetRange("Document No.", PurchRcptLine."Document No.");
            ItemLedgerEntry.SetRange("Document Line No.", PurchRcptLine."Line No.");
            ItemLedgerEntry.SetLoadFields("Invoiced Quantity", "Entry No.");
            ItemLedgerEntry.FindSet();
            repeat
                InvoicedQuantity += ItemLedgerEntry."Invoiced Quantity";
                if ItemApplicationEntry.AppliedOutbndEntryExists(ItemLedgerEntry."Entry No.", false, false) then
                    repeat
                        if ItemApplicationEntry."Item Ledger Entry No." = ItemApplicationEntry."Outbound Item Entry No." then begin
                            ReturnedInvoicedItemLedgerEntry.Get(ItemApplicationEntry."Item Ledger Entry No.");
                            if IsCancelled(ReturnedInvoicedItemLedgerEntry) then
                                ReturnedInvoicedQuantity += ReturnedInvoicedItemLedgerEntry."Invoiced Quantity";
                        end;
                    until ItemApplicationEntry.Next() = 0;
            until ItemLedgerEntry.Next() = 0;
            exit(InvoicedQuantity + ReturnedInvoicedQuantity <> 0);
        end else begin
            PurchInvLine.SetRange("Order No.", PurchRcptLine."Order No.");
            PurchInvLine.SetRange("Order Line No.", PurchRcptLine."Order Line No.");
            if PurchInvLine.FindSet() then
                repeat
                    PurchInvHeader.Get(PurchInvLine."Document No.");
                    PurchInvHeader.CalcFields(Cancelled);
                    if not PurchInvHeader.Cancelled then
                        exit(true);
                until PurchInvLine.Next() = 0;

            exit(false);
        end;
    end;

    local procedure IsCancelled(ItemLedgerEntry: Record "Item Ledger Entry"): Boolean
    var
        CancelledDocument: Record "Cancelled Document";
        ReturnShipmentHeader: Record "Return Shipment Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
    begin
        case ItemLedgerEntry."Document Type" of
            ItemLedgerEntry."Document Type"::"Purchase Return Shipment":
                begin
                    ReturnShipmentHeader.Get(ItemLedgerEntry."Document No.");
                    if ReturnShipmentHeader."Applies-to Doc. Type" = ReturnShipmentHeader."Applies-to Doc. Type"::Invoice then
                        exit(CancelledDocument.Get(Database::"Purch. Inv. Header", ReturnShipmentHeader."Applies-to Doc. No."));
                end;
            ItemLedgerEntry."Document Type"::"Purchase Credit Memo":
                begin
                    PurchCrMemoHdr.Get(ItemLedgerEntry."Document No.");
                    if PurchCrMemoHdr."Applies-to Doc. Type" = PurchCrMemoHdr."Applies-to Doc. Type"::Invoice then
                        exit(CancelledDocument.Get(Database::"Purch. Inv. Header", PurchCrMemoHdr."Applies-to Doc. No."));
                end;
        end;

        exit(false);
    end;

    local procedure PostItemJnlLine(PurchRcptLine: Record "Purch. Rcpt. Line"; var DocLineNo: Integer): Integer
    var
        ItemJnlLine: Record "Item Journal Line";
        PurchLine: Record "Purchase Line";
        PurchRcptHeader: Record "Purch. Rcpt. Header";
        SourceCodeSetup: Record "Source Code Setup";
        TempApplyToEntryList: Record "Item Ledger Entry" temporary;
        ItemApplicationEntry: Record "Item Application Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        Item: Record Item;
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        ItemLedgEntryNo: Integer;
        ItemRcptEntryNo: Integer;
        ItemShptEntryNo: Integer;
        IsHandled: Boolean;
        NewDocLineNo: Integer;
    begin
        IsHandled := false;
        // OnBeforePostItemJnlLine(PurchRcptLine, DocLineNo, ItemLedgEntryNo, IsHandled, NewDocLineNo);
        if NewDocLineNo > DocLineNo then
            DocLineNo := NewDocLineNo;
        if IsHandled then
            exit(ItemLedgEntryNo);

        with PurchRcptLine do begin
            if NewDocLineNo = 0 then
                DocLineNo := GetCorrectionLineNo(PurchRcptLine);

            SourceCodeSetup.Get();
            PurchRcptHeader.Get("Document No.");
            ItemJnlLine.Init();
            ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Purchase;
            ItemJnlLine."Item No." := "No.";
            ItemJnlLine."Posting Date" := PurchRcptHeader."Posting Date";
            ItemJnlLine."Document No." := "Document No.";
            ItemJnlLine."Document Line No." := DocLineNo;
            ItemJnlLine."Document Type" := ItemJnlLine."Document Type"::"Purchase Receipt";
            ItemJnlLine."Gen. Bus. Posting Group" := "Gen. Bus. Posting Group";
            ItemJnlLine."Gen. Prod. Posting Group" := "Gen. Prod. Posting Group";
            ItemJnlLine."Location Code" := "Location Code";
            ItemJnlLine."Source Code" := SourceCodeSetup.Purchases;
            ItemJnlLine."Variant Code" := "Variant Code";
            ItemJnlLine."Bin Code" := "Bin Code";
            ItemJnlLine."Unit of Measure Code" := "Unit of Measure Code";
            ItemJnlLine."Qty. per Unit of Measure" := "Qty. per Unit of Measure";
            ItemJnlLine."Document Date" := PurchRcptHeader."Document Date";
            ItemJnlLine."Shortcut Dimension 1 Code" := "Shortcut Dimension 1 Code";
            ItemJnlLine."Shortcut Dimension 2 Code" := "Shortcut Dimension 2 Code";
            ItemJnlLine."Dimension Set ID" := "Dimension Set ID";

            if "Job No." = '' then begin
                ItemJnlLine.Correction := true;
                ItemJnlLine."Applies-to Entry" := "Item Rcpt. Entry No.";
            end else begin
                ItemJnlLine."Job No." := "Job No.";
                ItemJnlLine."Job Task No." := "Job Task No.";
                ItemJnlLine."Job Purchase" := true;
                ItemJnlLine."Unit Cost" := "Unit Cost (LCY)";
            end;
            ItemJnlLine.Quantity := -(Quantity - "Quantity Invoiced");
            ItemJnlLine."Quantity (Base)" := -("Quantity (Base)" - "Qty. Invoiced (Base)");

            //OnAfterCopyItemJnlLineFromPurchRcpt(ItemJnlLine, PurchRcptHeader, PurchRcptLine, WhseUndoQty);

            WhseUndoQty.InsertTempWhseJnlLine(ItemJnlLine,
              DATABASE::"Purchase Line", PurchLine."Document Type"::Order.AsInteger(), "Order No.", "Order Line No.",
              TempWhseJnlLine."Reference Document"::"Posted Rcpt.".AsInteger(), TempWhseJnlLine, NextLineNo);
            //OnPostItemJnlLineOnAfterInsertTempWhseJnlLine(PurchRcptLine, ItemJnlLine, TempWhseJnlLine, NextLineNo);

            if "Item Rcpt. Entry No." <> 0 then begin
                if "Job No." <> '' then
                    UndoPostingMgt.TransferSourceValues(ItemJnlLine, "Item Rcpt. Entry No.");

                IsHandled := false;
                //OnPostItemJnlLineOnBeforeUndoPosting(ItemJnlLine, PurchRcptHeader, PurchRcptLine, SourceCodeSetup, IsHandled);
                if IsHandled then
                    exit(ItemJnlLine."Item Shpt. Entry No.");

                UndoPostingMgt.PostItemJnlLine(ItemJnlLine);

                IsHandled := false;
                //OnPostItemJnlLineOnBeforeUndoValuePostingWithJob(PurchRcptHeader, PurchRcptLine, ItemJnlLine, IsHandled);
                if not IsHandled then
                    if "Job No." <> '' then begin
                        Item.Get("No.");
                        if Item.Type = Item.Type::Inventory then begin
                            ItemLedgerEntry.Get("Item Rcpt. Entry No.");
                            if ItemLedgerEntry.Positive then begin
                                ItemRcptEntryNo := "Item Rcpt. Entry No.";
                                ItemShptEntryNo := ItemJnlLine."Item Shpt. Entry No.";
                            end else begin
                                ItemApplicationEntry.GetInboundEntriesTheOutbndEntryAppliedTo("Item Rcpt. Entry No.");
                                ItemRcptEntryNo := ItemApplicationEntry."Inbound Item Entry No.";
                                ItemApplicationEntry.GetOutboundEntriesAppliedToTheInboundEntry(ItemJnlLine."Item Shpt. Entry No.");
                                ItemShptEntryNo := ItemApplicationEntry."Outbound Item Entry No.";
                            end;
                            UndoPostingMgt.FindItemReceiptApplication(ItemApplicationEntry, ItemRcptEntryNo);
                            ItemJnlPostLine.UndoValuePostingWithJob(
                              ItemRcptEntryNo, ItemApplicationEntry."Outbound Item Entry No.");
                            IsHandled := false;
                            //OnPostItemJournalInboundItemEntryPostingWithJob(ItemJnlLine, ItemApplicationEntry, IsHandled);
                            if not IsHandled then begin
                                UndoPostingMgt.FindItemShipmentApplication(ItemApplicationEntry, ItemShptEntryNo);
                                ItemJnlPostLine.UndoValuePostingWithJob(
                                  ItemApplicationEntry."Inbound Item Entry No.", ItemShptEntryNo);
                            end;
                            Clear(UndoPostingMgt);
                            UndoPostingMgt.ReapplyJobConsumption(ItemRcptEntryNo);
                        end;
                    end;

                exit(ItemShptEntryNo);
            end;

            UndoPostingMgt.CollectItemLedgEntries(
              TempApplyToEntryList, DATABASE::"Purch. Rcpt. Line", "Document No.", "Line No.", "Quantity (Base)", "Item Rcpt. Entry No.");

            // IsHandled := false;
            // OnPostItemJnlLineOnAfterCollectItemLedgEntries(PurchRcptHeader, PurchRcptLine, SourceCodeSetup, IsHandled);
            // if IsHandled then
            //     exit(0); // "Item Shpt. Entry No."

            if "Job No." <> '' then
                ReapplyJobConsumptionFromApplyToEntryList(PurchRcptHeader, PurchRcptLine, ItemJnlLine, TempApplyToEntryList);

            UndoPostingMgt.PostItemJnlLineAppliedToList(ItemJnlLine, TempApplyToEntryList,
              Quantity - "Quantity Invoiced", "Quantity (Base)" - "Qty. Invoiced (Base)", TempGlobalItemLedgEntry, TempGlobalItemEntryRelation, "Qty. Rcd. Not Invoiced" <> Quantity);

            exit(0); // "Item Shpt. Entry No."
        end;
    end;

    local procedure GetCorrectionLineNo(PurchRcptLine: Record "Purch. Rcpt. Line") Result: Integer
    var
        PurchRcptLine2: Record "Purch. Rcpt. Line";
        LineSpacing: Integer;
        IsHandled: Boolean;
        Text002: Label 'There is not enough space to insert correction lines.';
    begin
        // IsHandled := false;
        // OnBeforeGetCorrectionLineNo(PurchRcptLine, Result, IsHandled);
        // if IsHandled then
        //     exit(Result);

        with PurchRcptLine do begin
            PurchRcptLine2.SetRange("Document No.", "Document No.");
            PurchRcptLine2."Document No." := "Document No.";
            PurchRcptLine2."Line No." := "Line No.";
            PurchRcptLine2.Find('=');

            if PurchRcptLine2.Find('>') then begin
                LineSpacing := (PurchRcptLine2."Line No." - "Line No.") div 2;
                if LineSpacing = 0 then
                    Error(Text002);
            end else
                LineSpacing := 10000;
            exit("Line No." + LineSpacing);
        end;
    end;

    local procedure ReapplyJobConsumptionFromApplyToEntryList(PurchRcptHeader: Record "Purch. Rcpt. Header"; PurchRcptLine: Record "Purch. Rcpt. Line"; ItemJnlLine: Record "Item Journal Line"; var TempApplyToEntryList: Record "Item Ledger Entry" temporary)
    var
        IsHandled: Boolean;
    begin
        // IsHandled := false;
        // OnBeforeReapplyJobConsumptionFromApplyToEntryList(PurchRcptHeader, PurchRcptLine, ItemJnlLine, TempApplyToEntryList, IsHandled);
        // if IsHandled then
        //     exit;

        if TempApplyToEntryList.FindSet() then
            repeat
                UndoPostingMgt.ReapplyJobConsumption(TempApplyToEntryList."Entry No.");
            until TempApplyToEntryList.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Page, Page::"Posted Sales Document Lines", 'OnCopyLineToDocOnBeforeMessage', '', true, true)]
    local procedure "Posted Sales Document Lines_OnCopyLineToDocOnBeforeMessage"
       (
           ToSalesHeader: Record "Sales Header";
           var IsHandled: Boolean
       )
    var
        SaleLine: Record "Sales Line";
        SaleLine1: Record "Sales Line";
    begin
        SaleLine.Reset();
        SaleLine.SetRange("Document No.", ToSalesHeader."No.");
        SaleLine.SetFilter(Type, '<>%1', SaleLine.Type::" ");
        SaleLine.SetRange(Exempted, true);
        if SaleLine.FindFirst() then
            repeat
                SaleLine."GST Exempt" := true;
                SaleLine.Modify();
                SaleLine1.Reset();
                SaleLine1.SetRange("Document No.", ToSalesHeader."No.");
                SaleLine1.SetRange(Type, SaleLine1.Type::" ");
                if SaleLine1.FindFirst() then
                    repeat
                        SaleLine1.Exempted := true;
                        SaleLine1."GST Exempt" := true;
                        SaleLine1.Modify();
                    until SaleLine1.Next() = 0;
            until SaleLine.Next() = 0;


    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Record Restriction Mgt.", 'OnBeforeCustomerCheckSalesPostRestrictions', '', true, true)]
    local procedure "Record Restriction Mgt._OnBeforeCustomerCheckSalesPostRestrictions"
    (
        var SalesHeader: Record "Sales Header";
        var IsHandled: Boolean
    )
    begin
        IsHandled := true;
    end;



    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeConfirmUpdateAllLineDim', '', true, true)]
    local procedure "Sales Header_OnBeforeConfirmUpdateAllLineDim"
    (
        var SalesHeader: Record "Sales Header";
        var xSalesHeader: Record "Sales Header";
        NewParentDimSetID: Integer;
        OldParentDimSetID: Integer;
        var Confirmed: Boolean;
        var IsHandled: Boolean
    )
    begin
        IsHandled := true;
        Confirmed := true;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Copy Document Mgt.", 'OnAfterCopySalesDocument', '', true, true)]
    local procedure "Copy Document Mgt._OnAfterCopySalesDocument"
    (
        FromDocumentType: Option;
        FromDocumentNo: Code[20];
        var ToSalesHeader: Record "Sales Header";
        FromDocOccurenceNo: Integer;
        FromDocVersionNo: Integer;
        IncludeHeader: Boolean;
        RecalculateLines: Boolean;
        MoveNegLines: Boolean
    )
    var
        PORec: Record "Purchase Header";
        PRH: Record "Purch. Rcpt. Header";
        PIH: Record "Purch. Inv. Header";
        PCM: Record "Purch. Cr. Memo Hdr.";
        SIH: Record "Sales Invoice Header";
        SCM: Record "Sales Cr.Memo Header";
        SSH: Record "Sales Shipment Header";
        PurchasHe: Record "Sales Header";
    begin
        //  Message('%1..%2..%3..%4..%5', FromDocumentType, FromDocumentNo, ToPurchaseHeader."Shortcut Dimension 1 Code", ToPurchaseHeader."Shortcut Dimension 2 Code", ToPurchaseHeader."Shortcut Dimension 3 Code");
        if PRH.Get(FromDocumentNo) then begin
            ToSalesHeader.Validate("Shortcut Dimension 1 Code", PRH."Shortcut Dimension 1 Code");
            ToSalesHeader.Validate("Shortcut Dimension 2 Code", PRH."Shortcut Dimension 2 Code");
            ToSalesHeader.Validate("Shortcut Dimension 3 Code", PRH."Shortcut Dimension 3 Code");
        end else
            if PIH.Get(FromDocumentNo) then begin
                ToSalesHeader.Validate("Shortcut Dimension 1 Code", PIH."Shortcut Dimension 1 Code");
                ToSalesHeader.Validate("Shortcut Dimension 2 Code", PIH."Shortcut Dimension 2 Code");
                ToSalesHeader.Validate("Shortcut Dimension 3 Code", PIH."Shortcut Dimension 3 Code");
            end else
                if PCM.Get(FromDocumentNo) then begin
                    ToSalesHeader.Validate("Shortcut Dimension 1 Code", PCM."Shortcut Dimension 1 Code");
                    ToSalesHeader.Validate("Shortcut Dimension 2 Code", PCM."Shortcut Dimension 2 Code");
                    ToSalesHeader.Validate("Shortcut Dimension 3 Code", PCM."Shortcut Dimension 3 Code");
                END else
                    if SIH.Get(FromDocumentNo) then begin
                        ToSalesHeader.Validate("Shortcut Dimension 1 Code", SIH."Shortcut Dimension 1 Code");
                        ToSalesHeader.Validate("Shortcut Dimension 2 Code", SIH."Shortcut Dimension 2 Code");
                        ToSalesHeader.Validate("Shortcut Dimension 3 Code", SIH."Shortcut Dimension 3 Code");
                    END else
                        if SCM.Get(FromDocumentNo) then begin
                            ToSalesHeader.Validate("Shortcut Dimension 1 Code", SCM."Shortcut Dimension 1 Code");
                            ToSalesHeader.Validate("Shortcut Dimension 2 Code", SCM."Shortcut Dimension 2 Code");
                            ToSalesHeader.Validate("Shortcut Dimension 3 Code", SCM."Shortcut Dimension 3 Code");
                        END else
                            if SSH.Get(FromDocumentNo) then begin
                                ToSalesHeader.Validate("Shortcut Dimension 1 Code", SSH."Shortcut Dimension 1 Code");
                                ToSalesHeader.Validate("Shortcut Dimension 2 Code", SSH."Shortcut Dimension 2 Code");
                                ToSalesHeader.Validate("Shortcut Dimension 3 Code", SSH."Shortcut Dimension 3 Code");
                            END;
        PurchasHe.Reset();
        PurchasHe.SetRange("No.", FromDocumentNo);
        if PurchasHe.FindFirst() then begin
            ToSalesHeader.Validate("Shortcut Dimension 1 Code", PurchasHe."Shortcut Dimension 1 Code");
            ToSalesHeader.Validate("Shortcut Dimension 2 Code", PurchasHe."Shortcut Dimension 2 Code");
            ToSalesHeader.Validate("Shortcut Dimension 3 Code", PurchasHe."Shortcut Dimension 3 Code");
        end;
    END;





    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnAfterConfirmPost', '', true, true)]
    local procedure "Sales-Post (Yes/No)_OnAfterConfirmPost"(var SalesHeader: Record "Sales Header")
    var

        UserSetup: Record "User Setup";
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        GSTSetup1: Record "GST Setup";
        //TaxComponentName1: Record "Tax Component";
        TaxTransactionValue: Record "Tax Transaction Value";
        TaxComponentName1: Text;
        Companyinfo: Record "Company Information";
        CustLedger: Record "Cust. Ledger Entry";
        BaseAmt1: Decimal;
        Text50000: Label 'Please select the Nature of collection for Line No. %1';
        Text50001: Label 'Nature of Collection must be blank in Line No. %1';
        ExemptedLinesErr: Label 'All lines in the document are GST Exempted, the preferred Invoice type should be Bill of Supply.';
        NonExemptedLinesErr: Label 'All lines in the document are not GST Exempted, the preferred Invoice type should be according to GST Customer Type.';
    begin
        Companyinfo.Get;
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then begin
            UserSetup.RESET;
            UserSetup.SETRANGE("User ID", USERID);
            UserSetup.SETFILTER(UserSetup."Access Sales Order", '%1', UserSetup."Access Sales Order"::Ship);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Invoice THEN
                    ERROR('You do not have permission to Invoice Sales Order');
            END;
            UserSetup.SETFILTER(UserSetup."Access Sales Order", '%1', UserSetup."Access Sales Order"::Invoice);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Ship THEN
                    ERROR('You do not have permission to Ship Sales Order');
            END;
        END ELSE
            IF SalesHeader."Document Type" = SalesHeader."Document Type"::"Return Order" then begin
                //PRU-VG 1.10
                UserSetup.RESET;
                UserSetup.SETRANGE("User ID", USERID);
                UserSetup.SETFILTER(UserSetup."Access Sales Return Order", '%1', UserSetup."Access Sales Return Order"::Receive);
                IF UserSetup.FINDFIRST THEN BEGIN
                    IF SalesHeader.Invoice THEN
                        ERROR('You do not have permission to Invoice Sales Return Order');
                END;
                UserSetup.RESET;
                UserSetup.SETRANGE("User ID", USERID);
                UserSetup.SETFILTER(UserSetup."Access Sales Return Order", '%1', UserSetup."Access Sales Return Order"::Invoice);
                IF UserSetup.FINDFIRST THEN BEGIN
                    IF SalesHeader.Receive THEN
                        ERROR('You do not have permission to Receive Sales Return Order');
                END;
                //PRU-VG 1.10
            END;
        //PRU-VG 1.10

        IF SalesHeader.Invoice THEN BEGIN
            Customer.RESET;
            if SalesHeader."Posting Date" <= 20250331D Then
                IF Customer.GET(SalesHeader."Sell-to Customer No.") THEN BEGIN
                    IF Customer."TCS Sec 206" THEN BEGIN
                        SalesLine.RESET;
                        SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                        SalesLine.SETFILTER(SalesLine.Type, '%1', SalesLine.Type::Item);
                        SalesLine.SETFILTER(SalesLine."Qty. to Invoice", '<>%1', 0);
                        IF SalesLine.FINDSET THEN BEGIN
                            REPEAT
                                IF SalesLine."TCS Nature of Collection" = '' THEN
                                    ERROR(Text50000, SalesLine."Line No.");
                            UNTIL SalesLine.NEXT = 0;
                        END;
                    END ELSE BEGIN
                        SalesLine.RESET;
                        SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                        SalesLine.SETFILTER(SalesLine.Type, '%1', SalesLine.Type::Item);
                        SalesLine.SETFILTER(SalesLine."Qty. to Invoice", '<>%1', 0);
                        IF SalesLine.FINDSET THEN BEGIN
                            REPEAT
                                IF SalesLine."TCS Nature of Collection" <> '' THEN
                                    ERROR(Text50001, SalesLine."Line No.");
                            UNTIL SalesLine.NEXT = 0;
                        END;
                    END;
                END;
        END;
        // Suman 14-03-2024
        IF SalesHeader.Invoice Then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
            SalesLine.SetFilter("No.", '<>%1', '');
            If SalesLine.FindSet() then
                repeat
                    if SalesLine."No." <> 'DISCOUNT_REBATE' Then begin
                        if SalesLine."GST Group Code" = '' then
                            Error('Please update the GST Group Code');
                        if SalesLine."HSN/SAC Code" = '' then
                            Error('Please update the HSN/SAC Code');
                    end;
                UNTIL SalesLine.NEXT = 0;
        end;
        // Suman 14-03-2024
        //SKS
        if not CheckAllLinesExemptedSales(SalesHeader) and (SalesHeader."Invoice Type" <> SalesHeader."Invoice Type"::"Bill of Supply") then
            Error(ExemptedLinesErr);

        if CheckAllLinesExemptedSales(SalesHeader) and (SalesHeader."Invoice Type" = SalesHeader."Invoice Type"::"Bill of Supply") then
            Error(NonExemptedLinesErr);


    end;


    procedure CheckAllLinesExemptedSales(SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
        SalesLine1: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine1.CopyFilters(SalesLine);
        SalesLine1.SetRange(Exempted, true);
        if SalesLine.Count() <> SalesLine1.Count() then begin
            //     Message('%1..%2', SalesLine1.count(), SalesLine1.count());
            exit(true);
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnBeforeOnRun', '', true, true)]
    local procedure "Sales-Post (Yes/No)_OnBeforeOnRun"
    (var SalesHeader: Record "Sales Header")
    var
        SalesLine_Rec: Record "Sales Line";
        GSTSetup1: Record "GST Setup";
        //TaxComponentName1: Record "Tax Component";
        TaxTransactionValue: Record "Tax Transaction Value";
        BaseAmt: Decimal;
        TaxComponentName1: Text;
        BaseAmt1: Decimal;
    begin
        IF SalesHeader."Posting Date" <= 20210331D THEN
            ERROR('You Can Not Post the Transaction In Last Year');
        //Suman
        SalesLine_Rec.RESET;
        SalesLine_Rec.SETRANGE("Document Type", SalesHeader."Document Type");
        SalesLine_Rec.SETRANGE("Document No.", SalesHeader."No.");
        //SalesLine_Rec.SETRANGE("Responsibility Center",'%1|%2','CATTLE|FEED');
        SalesLine_Rec.SETFILTER("No.", '<>%1', '');
        //SalesLine_Rec.SETFILTER("Unit Price",'<>%1',0);
        IF SalesLine_Rec.FINDSET THEN
            REPEAT
                IF (SalesLine_Rec."Unit Price" = 0) THEN
                    ERROR('Unit price should not blank or Zero of %1', SalesLine_Rec."No.");
            // if (SalesLine_Rec."GST Group Code" = '') or (SalesLine_Rec."HSN/SAC Code" = '') then
            //     error('GST Group code and HSN Code should not be blank for line no. %1 and Item No. is %2', SalesLine_Rec."Line No.", SalesLine_Rec."No.");

            UNTIL SalesLine_Rec.NEXT = 0;
        //Suman
    end;


    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterCheckSellToCust', '', true, true)]
    local procedure "Sales Header_OnAfterCheckSellToCust"
    (
        var SalesHeader: Record "Sales Header";
        xSalesHeader: Record "Sales Header";
        Customer: Record "Customer";
        CurrentFieldNo: Integer
    )
    begin
        SalesHeader."P.A.N. No." := Customer."P.A.N. No."; //RK-PRU
    end;

    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnAfterCheckBillToCust', '', true, true)]
    local procedure "Sales Header_OnAfterCheckBillToCust"
    (
        var SalesHeader: Record "Sales Header";
        xSalesHeader: Record "Sales Header";
        Customer: Record "Customer"
    )
    begin
        SalesHeader.Freight := Customer."Freight Term";
        SalesHeader."Broker Code" := Customer."Broker Code";
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Reference Invoice No. Mgt.", 'OnBeforeCheckRefInvoiceNoSalesHeader', '', true, true)]
    local procedure "Reference Invoice No. Mgt._OnBeforeCheckRefInvoiceNoSalesHeader"
    (
        var SalesHeader: Record "Sales Header";
        var IsHandled: Boolean
    )
    begin
        if SalesHeader.Receive = true then
            IsHandled := true;
        if (SalesHeader.Receive = true) AND (SalesHeader.Invoice = true) then
            IsHandled := false;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Correct Posted Sales Invoice", 'OnBeforeSalesHeaderInsert', '', true, true)]
    local procedure "Correct Posted Sales Invoice_OnBeforeSalesHeaderInsert"
       (
           var SalesHeader: Record "Sales Header";
           var SalesInvoiceHeader: Record "Sales Invoice Header";
           CancellingOnly: Boolean
       )
    begin
        SalesHeader."Invoice Type" := SalesHeader."Invoice Type"::"Bill of Supply";

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Correct Posted Sales Invoice", 'OnAfterCreateCopyDocument', '', true, true)]
    local procedure "Correct Posted Sales Invoice_OnAfterCreateCopyDocument"
    (
        var SalesHeader: Record "Sales Header";
        var SalesInvoiceHeader: Record "Sales Invoice Header"
    )
    begin
        SalesHeader."Invoice Type" := SalesHeader."Invoice Type"::"Bill of Supply";

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Price Calculation Buffer Mgt.", 'OnAfterSetFilters', '', true, true)]
    local procedure "Price Calculation Buffer Mgt._OnAfterSetFilters"
    (
        var PriceListLine: Record "Price List Line";
        AmountType: Enum "Price Amount Type";
        var
            PriceCalculationBuffer: Record "Price Calculation Buffer";
            ShowAll: Boolean
    )
    begin
        PriceListLine.SetRange(MRP, true);

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Line - Price", 'OnAfterSetPrice', '', true, true)]
    local procedure "Sales Line - Price_OnAfterSetPrice"
    (
        var SalesLine: Record "Sales Line";
        PriceListLine: Record "Price List Line";
        AmountType: Enum "Price Amount Type"
    )
    var
        PriceListLine1: Record "Price List Line";
    begin
        IF PriceListLine.MRP THEN BEGIN
            SalesLine."MRP Price" := PriceListLine."MRP Price";
            SalesLine.MRP := PriceListLine.MRP;
            SalesLine."Total MRP" := PriceListLine."MRP Price" * SalesLine.Quantity;
        END;
    end;






    //For Old Sales Price Ye dalna hai

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales Price Calc. Mgt.", 'OnAfterFindSalesLineItemPrice', '', true, true)]
    local procedure "Sales Price Calc. Mgt._OnAfterFindSalesLineItemPrice"
    (
        var SalesLine: Record "Sales Line";
        var TempSalesPrice: Record "Sales Price";
        var FoundSalesPrice: Boolean;
        CalledByFieldNo: Integer
    )
    var
        SalesPrice: Record "Sales Price";
    begin
        if SalesLine."Qty. Shipped (Base)" = 0 then begin
            SalesLine."MRP Price" := TempSalesPrice."MRP Price";
            SalesLine.MRP := TempSalesPrice.MRP;
            SalesLine."Total MRP" := 0;
            SalesLine."Total MRP Price" := 0;
            SalesLine."Price Discount" := 0;

            IF TempSalesPrice.MRP THEN BEGIN
                SalesLine."MRP Price" := TempSalesPrice."MRP Price";
                SalesLine.MRP := TempSalesPrice.MRP;
                SalesLine."Total MRP Price" := TempSalesPrice."MRP PRICE" * SalesLine.Quantity;
                SalesLine."Total MRP" := TempSalesPrice."MRP PRICE" * SalesLine.Quantity;
                //   SalesLine."Abatement %" := TempSalesPrice."Abatement %";
            END;
        end;
    end;
    // Ye dalna Hai
    [EventSubscriber(ObjectType::Table, Database::"Item Journal Line", 'OnAfterCopyItemJnlLineFromSalesHeader', '', true, true)]
    local procedure OnAfterCopyItemJnlLineFromSalesHeader(var ItemJnlLine: Record "Item Journal Line"; SalesHeader: Record "Sales Header")
    begin
        ItemJnlLine.SFPLUserID := SalesHeader."SFPL User ID";
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostItemJnlLineBeforePost', '', true, true)]
    local procedure "Sales-Post_OnBeforePostItemJnlLineBeforePost"
    (
        SalesLine: Record "Sales Line";
        var ItemJnlLine: Record "Item Journal Line";
        var TempWhseJnlLine: Record "Warehouse Journal Line";
        Location: Record "Location";
        var PostWhseJnlLine: Boolean;
        QtyToBeShippedBase: Decimal;
        var IsHandled: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
    begin
        ItemJnlLine."Chicks Item" := SalesLine."Chicks Item"; //RK-PRU
        ItemJnlLine."Alternate Quantity" := SalesLine."Alternate Quantity";//PRU-VG
        ItemJnlLine."Alternate UOM" := SalesLine."Alternate UOM";//PRU-VG
        ItemJnlLine."Flock No." := SalesLine."Flock No.";//PRU-VG
        ItemJnlLine."Item Type" := SalesLine."Item Type";//PRU-VG
        SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
        ItemJnlLine.SFPLUserID := SalesHeader."SFPL User ID";
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnRunOnBeforeFinalizePosting', '', true, true)]
    local procedure "Sales-Post_OnRunOnBeforeFinalizePosting"
  (
      var SalesHeader: Record "Sales Header";
      var SalesShipmentHeader: Record "Sales Shipment Header";
      var SalesInvoiceHeader: Record "Sales Invoice Header";
      var SalesCrMemoHeader: Record "Sales Cr.Memo Header";
      var ReturnReceiptHeader: Record "Return Receipt Header";
      var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
      CommitIsSuppressed: Boolean;
      GenJnlLineExtDocNo: Code[35];
      var EverythingInvoiced: Boolean;
      GenJnlLineDocNo: Code[20];
      SrcCode: Code[10]
  )
    var
        T14: Record Location;
        GLSetupRec: Record 98;
        //C81: Codeunit 81;
        SalesShptHeader: Record 110;
        Cust: Record 18;
        T111: Record 111;
        T27: Record 27;

        GLEntry: Record "G/L Entry";
        SAlrec: Record "Sales & Receivables Setup";
        DetailGstENtry: Record "Detailed GST Ledger Entry";
        ReturnShipmentLine11: Record "Return Receipt Line";
        PurchInvLine11: Record "Sales Invoice Line";
        SalesInv_S: Record "Sales Invoice Line";
        PurchCrMemoLine11: Record "Sales Cr.Memo Line";
        SalesCR_S: Record "Sales Cr.Memo Line";
        PurchRcptLine1: Record "Purch. Rcpt. Line";
        GSTLedEntry: Record "GST Ledger Entry";
        ItemRec: Record Item;
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        SIH: Record "Sales Invoice Header";
        SCM: Record "Sales Cr.Memo Header";
        TCSEntry: record "TCS Entry";
        InvoiceAmt: Decimal;
        TCSInvoiceAmt: Decimal;
        TCSGST: Decimal;
    begin

        if SalesInvoiceHeader."No." <> '' Then begin
            SalesInv_S.Reset();
            SalesInv_S.SetRange("Document No.", SalesInvoiceHeader."No.");
            SalesInv_S.SetFilter("No.", '<>%1', '');
            SalesInv_S.SetFilter("GST Group Code", '<>%1', '');
            SalesInv_S.SetFilter("HSN/SAC Code", '<>%1', '');
            SalesInv_S.SetFilter(Quantity, '<>%1', 0);
            if SalesInv_S.FindSet() then
                repeat
                    DetailedGSTLedgerEntry.Reset();
                    DetailedGSTLedgerEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
                    DetailedGSTLedgerEntry.SetRange("Document Line No.", SalesInv_S."Line No.");
                    //DetGstLedEn.SetFilter("Buyer/Seller Reg. No.", '<>%1', PurchInvHeader."Location GST Reg. No.");
                    if DetailedGSTLedgerEntry.IsEmpty then
                        Error('GST Amount not calculated');

                Until SalesInv_S.Next() = 0;
        end;

        if SalesCrMemoHeader."No." <> '' Then begin
            SalesCR_S.Reset();
            SalesCR_S.SetRange("Document No.", SalesCrMemoHeader."No.");
            SalesCR_S.SetFilter("No.", '<>%1', '');
            SalesCR_S.SetFilter("GST Group Code", '<>%1', '');
            SalesCR_S.SetFilter("HSN/SAC Code", '<>%1', '');
            SalesCR_S.SetFilter(Quantity, '<>%1', 0);
            if SalesCR_S.FindSet() then
                repeat
                    DetailedGSTLedgerEntry.Reset();
                    DetailedGSTLedgerEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
                    DetailedGSTLedgerEntry.SetRange("Document Line No.", SalesCR_S."Line No.");
                    if DetailedGSTLedgerEntry.IsEmpty then
                        Error('GST Amount not calculated');
                Until SalesCR_S.Next() = 0;
        end;

        DetailedGSTLedgerEntry.Reset();
        //DetailedGSTLedgerEntry.SetRange("Entry Type", DetailedGSTLedgerEntry."Entry Type"::"Initial Entry");
        //DetailedGSTLedgerEntry.SetRange("Transaction Type", DetailedGSTLedgerEntry."Transaction Type"::Sales);
        //  DetailedGSTLedgerEntry.SetRange("Document Type", DetailedGSTLedgerEntry."Document Type"::Invoice);
        DetailedGSTLedgerEntry.SetRange("Document No.", SalesInvoiceHeader."No.");
        IF DetailedGSTLedgerEntry.FindSet() then
            repeat
                if SIH.Get(SalesInvoiceHeader."No.") then begin
                    DetailedGSTLedgerEntry."Source No." := SIH."Bill-to Customer No.";
                    DetailedGSTLedgerEntry.Modify();
                END;
            until DetailedGSTLedgerEntry.Next() = 0;

        DetailedGSTLedgerEntry.Reset();
        DetailedGSTLedgerEntry.SetRange("Document No.", SalesCrMemoHeader."No.");
        IF DetailedGSTLedgerEntry.FindSet() then
            repeat
                if SCM.Get(SalesCrMemoHeader."No.") then begin
                    DetailedGSTLedgerEntry."Source No." := SCM."Bill-to Customer No.";
                    DetailedGSTLedgerEntry.Modify();
                END;
            until DetailedGSTLedgerEntry.Next() = 0;

        DetailGstENtry.Reset();
        DetailGstENtry.SetRange(DetailGstENtry."Document Type", DetailGstENtry."Document Type"::Invoice);
        DetailGstENtry.SetRange("Document No.", SalesInvoiceHeader."No.");
        if DetailGstENtry.FindFirst() then
            repeat
                TCSGST += ABS(DetailedGSTLedgerEntry."GST Amount");

            until DetailGstENtry.Next() = 0;
        DetailGstENtry.Reset();
        DetailGstENtry.SetRange(DetailGstENtry."Document Type", DetailGstENtry."Document Type"::"Credit Memo");
        DetailGstENtry.SetRange("Document No.", SalesCrMemoHeader."No.");
        if DetailGstENtry.FindFirst() then
            repeat
                TCSGST += ABS(DetailedGSTLedgerEntry."GST Amount");

            until DetailGstENtry.Next() = 0;




    end;


    LOCAL procedure CheckMandatoryHeaderFields(SalesHeader: Record "Sales Header")
    begin
        IF (SalesHeader."Document Type" IN [SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo"]) AND SalesHeader.Trading THEN
            SalesHeader.TESTFIELD("Applies-to Doc. No.");
        SalesHeader.TESTFIELD("Document Type");
        SalesHeader.TESTFIELD("Sell-to Customer No.");
        SalesHeader.TESTFIELD("Bill-to Customer No.");
        SalesHeader.TESTFIELD("Posting Date");
        SalesHeader.TESTFIELD("Document Date");
    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostSalesDoc', '', true, true)]
    local procedure "Sales-Post_OnBeforePostSalesDoc"
    (
        var SalesHeader: Record "Sales Header";
        CommitIsSuppressed: Boolean;
        PreviewMode: Boolean;
        var HideProgressWindow: Boolean
    )
    var
        T27: Record 27;
        T14: Record 14;
        //  C50006: Codeunit 50006;
        Cust: Record 18;
        CustText: Text;
        CustRecordID: RecordID;
        ApprovalEntry_Loc: Record 454;
        CU50007: Codeunit 50007;
        GLSetupRec: Record 98;
        SalesLine_123: Record 37;
        DimensionSetEntry_123: Record 480;
        Customer_Tcs: Record 18;
        DimensionMaster: Record 50030;
        SI: Record 37;
        Sl: Record 37;
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        Text50000: Label 'Please select the Nature of collection for Line No. %1';
        Text50001: Label 'Nature oF Collection must be blank in Line No. %1';
        NoSeriesMgt: Codeunit NoSeriesManagement;
        SalesSetup1: Record "Responsibility Center";
        Location: Record Location;
        UserSetup: Record "User Setup";
        UserSetup1: Record "User Setup";
        SalesSetup: Record "Sales & Receivables Setup";
        GenJnlCheckLine: Codeunit 11;
        Text045: Label 'is not within your range of allowed posting dates.';
        SalesLine6: Record "Sales Line";
        ItemChargeAssgntSales2: Record 5809;
        ItemCharge: Record "Item Charge";
        Item: Record Item;
        C50006: Codeunit 50006;
        InvoiceCheck: Boolean;
        ExemptedLinesErr: Label 'All lines in the document are GST Exempted, the preferred Invoice type should be Bill of Supply.';
        NonExemptedLinesErr: Label 'All lines in the document are not GST Exempted, the preferred Invoice type should be according to GST Customer Type.';
        SLRec: Record "Sales Line";
        Customerrec: Record Customer;
        SLRec1: Record "Sales Line";
        ILE: Record "Item Ledger Entry";
        RemQty: Decimal;
        LOC1: Record Location;
        CompanyInfo: Record "Company Information";
        RecSL: Record "Sales Line";
        Testcost: Decimal;
        RecCustLedger: Record "Cust. Ledger Entry";
        Time1: Time;
        TimeChecking: Boolean;
        TaxTransValue1: Record "Tax Transaction Value";
        GSTSetup1: Record "GST Setup";
    begin
        CompanyInfo.Get;

        if Customerrec.get(SalesHeader."Sell-to Customer No.") then begin
            if ((Customerrec."Salesperson Code" <> '') OR (Customerrec."Salesperson Code 2" <> '') OR (Customerrec."Salesperson Code 3" <> '')) then
                if SalesHeader."Salesperson Code" = '' then
                    Error('Salesperson Code is mandatory for this order');
        END;

        SLRec.Reset();
        SLRec.SetRange("Document No.", SalesHeader."No.");
        SLRec.SetFilter("No.", '<>%1', '');
        if SLRec.FindFirst() then
            repeat
                SLRec1.Reset();
                SLRec1.SetRange("Document No.", SLRec."Document No.");
                SLRec1.SetFilter("Line No.", '<>%1', SLRec."Line No.");
                SLRec1.SetFilter("No.", '<>%1', '');
                if SLRec1.FindFirst() then
                    repeat
                        if SLRec.Exempted <> SLRec1.Exempted then
                            Error('Exempted are not same all line', SLRec1."Line No.");


                        // SUman 23-01-2023
                        if LOC1.Get(SalesHeader."Location Code") Then begin
                            if SLRec."GST Jurisdiction Type" = SLRec."GST Jurisdiction Type"::Interstate then begin
                                if Customerrec."State Code" = LOC1."State Code" then begin
                                    Error('Please check the GST Jurisdiction Type');
                                end;
                            end else
                                if SLRec."GST Jurisdiction Type" = SLRec."GST Jurisdiction Type"::Intrastate then begin
                                    if Customerrec."State Code" <> LOC1."State Code" then begin
                                        Error('Please check the GST Jurisdiction Type');
                                    end;
                                end;

                        end;

                    until SLRec1.Next() = 0;

                if SLRec."Location Code" <> SalesHeader."Location Code" then
                    Error('Line Location Code does not match from header Location on Line No. %1', SLRec."Line No.");
            until SLRec.Next() = 0;
        //Item ILE COde//

        SLRec.Reset();
        SLRec.SetRange("Document No.", SalesHeader."No.");
        if SLRec.FindFirst() then
            repeat
                SLRec."Variant Code" := '';
                SLRec.Modify();
            until SLRec.Next() = 0;
        if not CheckAllLinesExemptedSales(SalesHeader) and (SalesHeader."Invoice Type" <> SalesHeader."Invoice Type"::"Bill of Supply") then
            Error(ExemptedLinesErr);

        if CheckAllLinesExemptedSales(SalesHeader) and (SalesHeader."Invoice Type" = SalesHeader."Invoice Type"::"Bill of Supply") then
            Error(NonExemptedLinesErr);
        InvoiceCheck := false;
        if (SalesHeader.Ship = false) AND (SalesHeader.Invoice = false) then
            InvoiceCheck := true;
        if SalesHeader."Document Type" = SalesHeader."Document Type"::Order then begin
            UserSetup.RESET;
            UserSetup.SETRANGE("User ID", USERID);
            UserSetup.SETFILTER(UserSetup."Access Sales Order", '%1', UserSetup."Access Sales Order"::Ship);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Invoice THEN
                    ERROR('You do not have permission to Invoice Sales Order');
            END;
            UserSetup.SETFILTER(UserSetup."Access Sales Order", '%1', UserSetup."Access Sales Order"::Invoice);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Ship THEN
                    ERROR('You do not have permission to Ship Sales Order');
            END;
        end;
        if SalesHeader."Document Type" = SalesHeader."Document Type"::"Return Order" then begin
            //PRU-VG 1.10
            UserSetup.RESET;
            UserSetup.SETRANGE("User ID", USERID);
            UserSetup.SETFILTER(UserSetup."Access Sales Return Order", '%1', UserSetup."Access Sales Return Order"::Receive);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Invoice THEN
                    ERROR('You do not have permission to Invoice Sales Return Order');
            END;
            UserSetup.RESET;
            UserSetup.SETRANGE("User ID", USERID);
            UserSetup.SETFILTER(UserSetup."Access Sales Return Order", '%1', UserSetup."Access Sales Return Order"::Invoice);
            IF UserSetup.FINDFIRST THEN BEGIN
                IF SalesHeader.Receive THEN
                    ERROR('You do not have permission to Receive Sales Return Order');
            END;
            //PRU-VG 1.10
        END;
        //PRU-VG 1.10
        //>>PRU_RPG DM_0.1
        if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna Then Begin
            DimensionMaster.RESET;
            DimensionMaster.SETRANGE("Shortcut Dimension 1 Code", SalesHeader."Shortcut Dimension 1 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 2 Code", SalesHeader."Shortcut Dimension 2 Code");
            DimensionMaster.SETRANGE("Shortcut Dimension 3 Code", SalesHeader."Shortcut Dimension 3 Code");
            IF NOT DimensionMaster.FINDFIRST THEN
                ERROR('Dimension Master Does not exist');
        end;
        //<<PRU_RPG DM_0.1

        IF SalesHeader."Posting Date" < 20210331D THEN
            ERROR('You Can not Post Sales Entry in Last Year');

        ///Pru_gk DMV_.01
        SalesLine_123.RESET;
        SalesLine_123.SETRANGE("Document No.", SalesHeader."No.");
        SalesLine_123.SETFILTER(Type, '<>%1', SalesLine_123.Type::" ");
        IF SalesLine_123.FINDFIRST THEN
            REPEAT
                IF SalesLine_123."Shortcut Dimension 1 Code" <> SalesHeader."Shortcut Dimension 1 Code" THEN
                    ERROR('Sales lines %1 LOB Code is not match of sales header LOB Code', SalesLine_123."Line No.");
                IF SalesLine_123."Shortcut Dimension 2 Code" <> SalesHeader."Shortcut Dimension 2 Code" THEN
                    ERROR('Sales lines %1 Branch is not match of sales header Branch', SalesLine_123."Line No.");
                IF SalesLine_123."Dimension Set ID" <> SalesHeader."Dimension Set ID" THEN
                    ERROR('Sales lines %1 dimension set id is not match of sales header dimension set id', SalesLine_123."Line No.");
                DimensionSetEntry_123.RESET;
                DimensionSetEntry_123.SETRANGE("Dimension Set ID", SalesHeader."Dimension Set ID");
                IF DimensionSetEntry_123.FINDSET THEN
                    REPEAT
                        IF DimensionSetEntry_123."Dimension Code" = 'BRANCH' THEN BEGIN
                            IF DimensionSetEntry_123."Dimension Value Code" <> SalesHeader."Shortcut Dimension 2 Code" THEN
                                ERROR('Sales lines %1 Branch is not match of Sales header Branch', SalesLine_123."Line No.");
                        END;
                        IF DimensionSetEntry_123."Dimension Code" = 'LOB' THEN BEGIN
                            IF DimensionSetEntry_123."Dimension Value Code" <> SalesHeader."Shortcut Dimension 1 Code" THEN
                                ERROR('Sales lines %1 LOB Code is not match of Sales header LOB Code', SalesLine_123."Line No.");
                        END;
                        if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna Then
                            IF DimensionSetEntry_123."Dimension Code" = 'LOC' THEN BEGIN
                                IF DimensionSetEntry_123."Dimension Value Code" <> SalesHeader."Shortcut Dimension 3 Code" THEN
                                    ERROR('Sales lines %1 LOC Code is not match of Sales header LOC Code', SalesLine_123."Line No.");
                            END;
                    UNTIL DimensionSetEntry_123.NEXT = 0;
            UNTIL SalesLine_123.NEXT = 0;
        ///Pru_gk DMV_.01
        // end;
        CheckMandatoryHeaderFields(SalesHeader);
        IF GenJnlCheckLine.DateNotAllowed(SalesHeader."Posting Date") THEN
            SalesHeader.FIELDERROR("Posting Date", Text045);

        //GK
        SalesLine6.RESET;
        SalesLine6.SETRANGE("Document Type", SalesHeader."Document Type");
        SalesLine6.SETRANGE("Document No.", SalesHeader."No.");
        SalesLine6.SETRANGE(Type, SalesLine6.Type::"Charge (Item)");
        // SalesLine6.SETFILTER("Tax Amount", '<>%1', 0);
        IF SalesLine6.FINDSET THEN
            REPEAT
                ItemChargeAssgntSales2.RESET;
                ItemChargeAssgntSales2.SETRANGE("Document Type", SalesLine6."Document Type");
                ItemChargeAssgntSales2.SETRANGE("Document No.", SalesLine6."Document No.");
                ItemChargeAssgntSales2.SETRANGE("Document Line No.", SalesLine6."Line No.");
                IF ItemChargeAssgntSales2.FINDSET THEN
                    REPEAT
                        ItemCharge.GET(ItemChargeAssgntSales2."Item Charge No.");
                        Item.GET(ItemChargeAssgntSales2."Item No.");
                    //IF ItemCharge."Fixed Asset" <> Item."Fixed Asset" THEN
                    //  ERROR(STRSUBSTNO(Text16507, ItemCharge."Fixed Asset", ItemChargeAssgntSales2."Item No.",
                    //    ItemChargeAssgntSales2."Document Line No."));
                    UNTIL ItemChargeAssgntSales2.NEXT = 0;
            UNTIL SalesLine6.NEXT = 0;
        If ((SalesHeader."Shortcut Dimension 1 Code" = 'FEED') Or (SalesHeader."Shortcut Dimension 1 Code" = 'CATTLE')) Then begin
            IF (SalesHeader.Invoice OR InvoiceCheck) or (SalesHeader.Ship) THEN BEGIN
                if SalesHeader."Document Type" = SalesHeader."Document Type"::Order Then Begin
                    CompanyInfo.get;
                    Time1 := Time;
                    TimeChecking := False;
                    If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
                        UserSetup.Reset();
                        UserSetup.SetRange(UserSetup."User ID", UserId);
                        //UserSetup.SetRange("Global Dimension 1 Code", 'FEED|CATTLE');
                        UserSetup.SetRange("Tax Details Permission", True);
                        if not UserSetup.FindFirst() then
                            If SalesHeader."Posting Date" <> Today then Begin
                                if (Format(Time1) <= '11:00:00.000') Then
                                    TimeChecking := True;
                                if not TimeChecking Then
                                    Error('You can not post the Entry in back date, Current Date and Time in %1', CurrentDateTime);
                            End
                    End;
                end;
            end;
        end;
        If ((SalesHeader."Shortcut Dimension 1 Code" = 'CBF') Or (SalesHeader."Shortcut Dimension 1 Code" = 'BREEDER') Or (SalesHeader."Shortcut Dimension 1 Code" = 'HATCH')) Then begin
            IF (SalesHeader.Invoice OR InvoiceCheck) or (SalesHeader.Ship) THEN BEGIN
                if SalesHeader."Document Type" = SalesHeader."Document Type"::Order Then Begin
                    CompanyInfo.get;
                    Time1 := Time;
                    TimeChecking := False;
                    If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::Sampoorna] then begin
                        UserSetup.Reset();
                        UserSetup.SetRange(UserSetup."User ID", UserId);
                        //UserSetup.SetRange("Global Dimension 1 Code", 'FEED|CATTLE');
                        UserSetup.SetRange("Tax Details Permission", True);
                        if not UserSetup.FindFirst() then
                            If SalesHeader."Posting Date" <> Today then Begin
                                if SalesHeader."Posting Date" = (Today - 1) then begin
                                    if (Format(Time1) <= '15:00:00.000') Then
                                        TimeChecking := True;
                                end else
                                    Error('You can not post the Entry in back date, Current Date and Time in %1', CurrentDateTime);
                                if not TimeChecking Then
                                    Error('You can not post the Entry in back date, Current Date and Time in %1', CurrentDateTime);
                            End
                    End;
                end;
            end;
        end;

        IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
            RecSL.Reset();
            RecSL.SetRange("Document No.", SalesHeader."No.");
            RecSL.SetFilter("No.", '<>%1', '');
            RecSL.Setfilter(Quantity, '<>%1', 0);
            if RecSL.FindFirst() then
                repeat
                    //Message(Format(Round(((RecSL.Quantity * RecSL."Unit Price") - RecSL."Line Discount Amount"), 0.01, '=')));
                    if RecSL.Amount <> Round(((RecSL.Quantity * RecSL."Unit Price") - RecSL."Line Discount Amount"), 0.01, '=') then
                        Error('Amount is not matched with the Calculative amount of Line No. %1 and Line Amount %2, Calculative Amount %3', RecSL."Line No.", RecSL.Amount, Round(((RecSL.Quantity * RecSL."Unit Price") - RecSL."Line Discount Amount"), 0.01, '='));
                until RecSL.Next() = 0;

        END;

        //GK

        //GK-05-04-2021-
        // Error('%1..%2..%3', SalesHeader.Invoice, SalesHeader.Receive, SalesHeader.Ship);
        IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
            if SalesHeader."Posting Date" <= 20250331D then
                IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
                    Customer.RESET;
                    IF Customer.GET(SalesHeader."Sell-to Customer No.") THEN BEGIN
                        IF Customer."TCS Sec 206" THEN BEGIN
                            SalesLine.RESET;
                            SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                            SalesLine.SETFILTER(SalesLine.Type, '%1', SalesLine.Type::Item);
                            IF SalesLine.FINDSET THEN BEGIN
                                REPEAT
                                    IF SalesLine."TCS Nature of Collection" = '' THEN
                                        ERROR(Text50000, SalesLine."Line No.");
                                UNTIL SalesLine.NEXT = 0;
                            END;
                        END ELSE BEGIN
                            SalesLine.RESET;
                            SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                            SalesLine.SETFILTER(SalesLine.Type, '%1', SalesLine.Type::Item);
                            IF SalesLine.FINDSET THEN BEGIN
                                REPEAT
                                    IF SalesLine."TCS Nature of Collection" <> '' THEN
                                        ERROR(Text50001, SalesLine."Line No.");
                                UNTIL SalesLine.NEXT = 0;
                            END;
                        END;
                    END;
                END;
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetFilter(Type, '<>%1', SalesLine.Type::" ");
            SalesLine.SetFilter("No.", '<>%1', '');
            If SalesLine.FindSet() then
                repeat
                    if SalesLine."No." <> 'DISCOUNT_REBATE' Then begin
                        if SalesLine."GST Group Code" = '' then
                            Error('Please update the GST Group Code');
                        if SalesLine."HSN/SAC Code" = '' then
                            Error('Please update the HSN/SAC Code');
                    end;
                UNTIL SalesLine.NEXT = 0;
        END;



        IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
            IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
                Customer.RESET;
                IF Customer.GET(SalesHeader."Sell-to Customer No.") THEN BEGIN
                    if SalesHeader."Posting Date" <= 20250331D then
                        IF NOT Customer."TCS Sec 206" THEN BEGIN
                            SalesLine.RESET;
                            SalesLine.SETRANGE(SalesLine."Document No.", SalesHeader."No.");
                            SalesLine.SETFILTER(SalesLine.Type, '%1|%2', SalesLine.Type::Item, SalesLine.Type::"Charge (Item)");
                            IF SalesLine.FINDSET THEN BEGIN
                                REPEAT
                                    IF SalesLine."TCS Nature of Collection" <> '' THEN
                                        ERROR(Text50001, SalesLine."Line No.");
                                UNTIL SalesLine.NEXT = 0;
                            END;
                        END
                END;
            END;
        END;
        //
        IF SalesHeader.Invoice OR SalesHeader.Receive OR InvoiceCheck THEN BEGIN
            Customer.RESET;
            IF Customer.GET(SalesHeader."Sell-to Customer No.") THEN BEGIN
                IF Customer."Customer Type" <> Customer."Customer Type"::Direct THEN BEGIN
                    IF SalesHeader."Posting Date" >= 20210401D THEN BEGIN
                        Sl.RESET;
                        Sl.SETRANGE("Document Type", SalesHeader."Document Type");
                        Sl.SETRANGE("Document No.", SalesHeader."No.");
                        IF Sl.FINDFIRST THEN
                            REPEAT
                                IF (Sl.Type = Sl.Type::Item) OR (Sl.Type = Sl.Type::"Charge (Item)") THEN BEGIN
                                    IF Sl."Assessee Code" = '' THEN
                                        ERROR('Please Check Assessee Code it should not be blank');
                                END;
                            UNTIL Sl.NEXT = 0;
                    END;
                END;
            END;
        END;
        //Gk-05-04-2021+
        //GK21052021-
        IF ((SalesHeader.Invoice = TRUE) AND (SalesHeader.Ship = FALSE)) OR InvoiceCheck THEN BEGIN
            Sl.RESET;
            Sl.SETRANGE("Document Type", Sl."Document Type"::Order);
            Sl.SETRANGE("Document No.", SalesHeader."No.");
            IF Sl.FINDFIRST THEN
                REPEAT
                    IF Sl."Qty. to Invoice" > Sl."Qty. Shipped Not Invoiced" THEN
                        ERROR('You can not Invoice more than Shiped Qty');
                UNTIL Sl.NEXT = 0;
        END;

        IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
            Sl.RESET;
            Sl.SETRANGE("Document Type", Sl."Document Type");
            Sl.SETRANGE("Document No.", SalesHeader."No.");
            Sl.SETFILTER("No.", '<>%1', '');
            IF Sl.FINDFIRST THEN
                REPEAT
                    if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna Then
                        IF Sl."No." <> '135100' THEN
                            Sl.TESTFIELD("Unit of Measure Code");
                    if CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::"Star Foods" Then
                        IF Sl."No." <> '312700' THEN
                            Sl.TESTFIELD("Unit of Measure Code");
                UNTIL Sl.NEXT = 0;
        END;

        IF SalesHeader.Invoice OR InvoiceCheck THEN BEGIN
            Sl.RESET;
            Sl.SETRANGE("Document Type", SalesHeader."Document Type");
            Sl.SETRANGE("Document No.", SalesHeader."No.");
            Sl.SETFILTER("No.", '<>%1', '');
            Sl.SetFilter("GST Group Code", '<>%1', '');
            Sl.SetFilter("HSN/SAC Code", '<>%1', '');
            Sl.SetFilter(Sl."Qty. to Invoice", '<>%1', 0);
            IF Sl.FINDFIRST THEN
                REPEAT
                    GSTSetup1.Get;
                    TaxTransValue1.Reset();
                    TaxTransValue1.SetRange("Tax Type", GSTSetup1."GST Tax Type");
                    TaxTransValue1.SetRange("Tax Record ID", Sl.RecordId());
                    TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
                    //TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                    if TaxTransValue1.IsEmpty then
                        Error('GST Must be Calculated');

                UNTIL Sl.NEXT = 0;
        END;

        IF SalesHeader.Ship THEN
            IF NOT PreviewMode THEN
                C50006.CreditLimitUpdateOnCustomerShip(SalesHeader);



    END;
    //GK21052021+


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostCommitSalesDoc', '', true, true)]

    local procedure OnAfterUpdatePostingNosvarvar(SalesHeader: Record "Sales Header"; var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"; PreviewMode: Boolean; var ModifyHeader: Boolean; var CommitIsSuppressed: Boolean; var TempSalesLineGlobal: Record "Sales Line" temporary)
    var
        PostedInvoice: Record "Sales Invoice Header";
        PostedNo: Code[20];
        InvoiceCheck: Boolean;
    begin
        InvoiceCheck := false;
        if (SalesHeader.Ship = false) AND (SalesHeader.Invoice = false) then
            InvoiceCheck := true;



    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostSalesDoc', '', true, true)]
    local procedure "Sales-Post_OnAfterPostSalesDoc"
    (
        var SalesHeader: Record "Sales Header";
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
        SalesShptHdrNo: Code[20];
        RetRcpHdrNo: Code[20];
        SalesInvHdrNo: Code[20];
        SalesCrMemoHdrNo: Code[20];
        CommitIsSuppressed: Boolean;
        InvtPickPutaway: Boolean;
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        WhseShip: Boolean;
        WhseReceiv: Boolean
    )
    var
        T14: Record Location;
        GLSetupRec: Record 98;
        C81: Codeunit 81;
        SalesShptHeader: Record 110;
        Cust: Record 18;
        T111: Record 111;
        T27: Record 27;
        SalesInvoiceHeader: Record 112;
        SalesShipmentHeader: Record 110;
        SalesCrMemoHeader1: Record 114;
        ReturnReceiptHeader: Record 6660;
        GLSetupRec1: Record "General Ledger Setup";
        SalesInvoiceHeader1: Record 112;
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        SIH: Record "Sales Invoice Header";
        SCM: Record "Sales Cr.Memo Header";
        CompanyInfo: Record "Company Information";
        Salesteam: Record "Team Salesperson";
        Team: Record Team;
    begin
        CompanyInfo.Get;
        // PRU_AS - 04 Dec 2019 START

        GLSetupRec1.GET;
        IF GLSetupRec1."Run SMS" = TRUE THEN BEGIN
            //RK-PRU
            IF (SalesHeader.Ship AND SalesHeader.Invoice) OR SalesHeader.Ship THEN BEGIN
                SalesHeader."Shipment Date" := WORKDATE;
                if SalesShptHeader.Get(SalesShptHdrNo) then
                    If CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna then begin
                        Salesteam.Reset();
                        Salesteam.SetRange("Salesperson Code", SalesShptHeader."Salesperson Code");
                        //Salesteam.SetRange("Team Code", 'PUNJAB');
                        if Salesteam.FindFirst() then begin
                            Team.Get(Salesteam."Team Code");
                            if Team."Delivery OTP" then
                                OTPSMS(SalesShptHeader);
                        end;
                        SMSSend(SalesShptHeader);
                    end;

            END;
            IF (SalesHeader.Ship AND SalesHeader.Invoice) OR SalesHeader.Invoice THEN;
            if SalesInvHdrNo <> '' then begin
                if SalesInvoiceHeader1.get(SalesInvHdrNo) then
                    SMSSendAtInvoice(SalesInvoiceHeader1);

            END;
            /// PRU_AS - 21 NOV 2019 END
        END;
        ///PRU-VG
        IF SalesHeader.Invoice THEN BEGIN
            Cust.GET(SalesHeader."Sell-to Customer No.");
            Cust.CALCFIELDS("Balance (LCY)", "Shipped Not Invoiced (LCY)");
            Cust."Remaining Credit Limit" := Cust."Credit Limit (LCY)" - (Cust."Balance (LCY)" + Cust."Shipped Not Invoiced (LCY)");
            Cust.MODIFY;
        END;


        ///PRU-VG
        //RK-PRU
        if SalesShptHeader.Get(SalesShptHdrNo) then;
        IF (SalesHeader.Ship AND SalesHeader.Invoice) OR SalesHeader.Ship THEN BEGIN
            T111.RESET;
            T111.SETRANGE("Document No.", SalesShptHeader."No.");
            T111.SETRANGE(Type, T111.Type::Item);
            T111.SETRANGE("Item Type", T111."Item Type"::Chick);
            T111.SETRANGE("Location Code", SalesShptHeader."Location Code");
            IF T111.FINDFIRST THEN BEGIN

                T27.RESET;
                T27.SETRANGE("No.", T111."No.");
                T27.SETRANGE("Location Filter", T111."Location Code");
                T27.SETAUTOCALCFIELDS(Inventory);
                IF T27.FINDFIRST THEN
                    IF T27.Inventory = 0 THEN BEGIN
                        T14.GET(T111."Location Code");
                        if T14."Responsibility Center" = 'CBF' then
                            T14."Liquidation Date" := SalesShptHeader."Posting Date";
                        T14.MODIFY;
                    END;

            END;
        END;

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnAfterPostItemJnlLine', '', true, true)]
    local procedure "Sales-Post_OnAfterPostItemJnlLine"
    (
        var ItemJournalLine: Record "Item Journal Line";
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        var WhseJnlPostLine: Codeunit "Whse. Jnl.-Register Line"
    )
    begin
        ItemJournalLine."Shortcut Dimension 3 Code" := SalesHeader."Shortcut Dimension 3 Code";
        ItemJournalLine."Chicks Item" := SalesLine."Chicks Item"; //RK-PRU
        ItemJournalLine."Alternate Quantity" := SalesLine."Alternate Quantity";//PRU-VG
        ItemJournalLine."Alternate UOM" := SalesLine."Alternate UOM";//PRU-VG
        ItemJournalLine."Flock No." := SalesLine."Flock No.";//PRU-VG
        ItemJournalLine."Item Type" := SalesLine."Item Type";//PRU-VG
        ItemJournalLine."Shortcut Dimension 3 Code" := SalesHeader."Shortcut Dimension 3 Code";  //Pru_gk
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post", 'OnBeforePostCustomerEntry', '', true, true)]
    local procedure "Sales-Post_OnBeforePostCustomerEntry"
    (
        var GenJnlLine: Record "Gen. Journal Line";
        var SalesHeader: Record "Sales Header";
        var TotalSalesLine: Record "Sales Line";
        var TotalSalesLineLCY: Record "Sales Line";
        CommitIsSuppressed: Boolean;
        PreviewMode: Boolean;
        var GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line"
    )
    begin
        GenJnlLine."Line Narration1" := SalesHeader."Line Narration";// SUman
        IF TotalSalesLine."GST Place of Supply" = TotalSalesLine."GST Place of Supply"::"Ship-to Address" THEN
            GenJnlLine."Account No." := SalesHeader."Sell-to Customer No."
        ELSE
            GenJnlLine."Account No." := SalesHeader."Bill-to Customer No.";
        GenJnlLine."Team Code" := SalesHeader."Team Code";
        GenJnlLine."User ID" := SalesHeader."SFPL User ID";
    end;


    procedure SMSSend(VAR ParaSaleShptsheader: Record "Sales Shipment Header")
    var
        CustomerPhone: Text[50];
        ShiptoAdd: Record "Ship-to Address";
        SalespersonRec: Record "Salesperson/Purchaser";
        SalespersonPhone: Text;
        TotalQuantity: Decimal;
        TotalAmount: Decimal;
        SMSBody: Text;
        CustomerInfo: Record Customer;
        ParaSalesShptLine: Record "Sales Shipment Line";
        PhoneNo: Text;
        PSShptLine: Record "Sales Shipment Line";
        FeedTxt: Text;
        SalesHeader: Record "Sales Header";
        SMSfunctions: Codeunit "SMS functions";
        SMSLine: Integer;
        PrevSMSBody: Text;
        PreFeedText: Text;
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        Customername: Text;
        Team: Record Team;
        SalesPersonTeam: Record "Team Salesperson";
        TeamPhone: Text;
        OTPSMSBody: Text;
        OTP: Integer;
        SalesRece: Record "Sales & Receivables Setup";
        WhatsAppSMS: Codeunit "WhatsApp Function";
        ShiptoPhone: Text;
        SMSDetail: Codeunit "SMS Details";
        NumberList: List of [Text];
        Number: Text;

    begin
        BEGIN
            SalesRece.Get;

            CustomerPhone := '';

            IF CustomerInfo.GET(ParaSaleShptsheader."Sell-to Customer No.") THEN BEGIN
                IF CustomerInfo."Phone No." <> '' THEN BEGIN
                    CustomerPhone := CustomerInfo."Phone No.";
                END ELSE BEGIN
                    MESSAGE('Customer no. not found in Customer card.');
                END;
            END;
            ////END;

            IF SalespersonRec.GET(ParaSaleShptsheader."Salesperson Code") THEN BEGIN
                SalespersonPhone := '';
                IF SalespersonRec."Phone No." <> '' THEN BEGIN
                    SalespersonPhone := SalespersonRec."Phone No.";
                END ELSE BEGIN
                    MESSAGE('Sale person contact no. not found');
                END;
            END;

            IF (ParaSaleShptsheader."Shortcut Dimension 1 Code" = 'CATTLE') or (ParaSaleShptsheader."Shortcut Dimension 1 Code" = 'SWINE') THEN BEGIN
                SalesPersonTeam.RESET;
                SalesPersonTeam.SETRANGE(SalesPersonTeam."Salesperson Code", ParaSaleShptsheader."Salesperson Code");
                IF SalesPersonTeam.FINDFIRST THEN begin
                    Team.RESET;
                    Team.SETRANGE(Team.Code, SalesPersonTeam."Team Code");
                    IF Team.FINDFIRST THEN
                        TeamPhone := Team."Team Phone No.";
                end;
            END;

            CLEAR(FeedTxt);
            PSShptLine.RESET;
            PSShptLine.SETRANGE("Document No.", ParaSaleShptsheader."No.");
            PSShptLine.SETFILTER(Quantity, '<>%1', 0);
            PSShptLine.SETFILTER("Shortcut Dimension 1 Code", '%1|%2|%3', 'FEED', 'CATTLE', 'SWINE');
            IF PSShptLine.FINDSET THEN
                REPEAT
                //FeedTxt += PSShptLine.Description+' '+FORMAT(PSShptLine.Quantity)+' '+'Bag'+' ';
                UNTIL PSShptLine.NEXT = 0;
            Clear(ShiptoPhone);
            CLEAR(Customername);
            IF ParaSaleShptsheader."Ship-to Code" <> '' THEN BEGIN
                Customername := COPYSTR(ParaSaleShptsheader."Ship-to Name", 1, 30);
                ShiptoPhone := ParaSaleShptsheader."Phone No.";
            END ELSE
                Customername := COPYSTR(ParaSaleShptsheader."Bill-to Name", 1, 30);


            //PruRaj
            TotalQuantity := 0;
            TotalAmount := 0;
            ParaSalesShptLine.RESET;
            ParaSalesShptLine.SETRANGE("Document No.", ParaSaleShptsheader."No.");
            ParaSalesShptLine.SETFILTER(Quantity, '<>%1', 0);
            ParaSalesShptLine.SETFILTER("Shortcut Dimension 1 Code", '%1|%2|%3', 'FEED', 'CATTLE', 'SWINE');
            IF ParaSalesShptLine.FINDSET THEN BEGIN
                REPEAT

                    IF ParaSalesShptLine.Type = ParaSalesShptLine.Type::Item THEN BEGIN
                        // IF CustomerPhone <> '' THEN BEGIN
                        SMSLine += 1;
                        FeedTxt += ParaSalesShptLine.Description + ' ' + FORMAT(ParaSalesShptLine.Quantity) + ' ' + 'Bag' + ' ' + ',' + ' ';
                        IF SMSLine = 3 THEN BEGIN
                            SMSBody := 'Dear' + ' ' +
                           FORMAT(Customername) + ' ' + 'Your Order with' + ' ' + FeedTxt + 'is Dispatched vide, Vehicle No.:-' +
                           FORMAT(ParaSaleShptsheader."Vehicle No.") + ' ' + 'Driver Mob No.:-' + FORMAT(ParaSaleShptsheader."Driver Mobile No.") + ',' + ' Sampoorna Feeds Pvt Ltd.';
                            //MESSAGE(SMSBody);
                            SMSLine := 0;
                            FeedTxt := '';
                            //SMSfunctions.SendSMSByURL(SMSBody);
                            Clear(NumberList);
                            if ShiptoPhone <> '' Then begin
                                NumberList := ShiptoPhone.Split(',');
                                foreach Number in NumberList do begin
                                    SMSDetail.APISMSSingalNo(Number, SMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                                end;
                            end;
                            // if CustomerPhone <> '' Then
                            //     WhatsAppSMS.SendSMS(CustomerPhone, SMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                            // if SalespersonPhone <> '' Then
                            //     WhatsAppSMS.SendSMS(SalespersonPhone, SMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                            if TeamPhone <> '' Then begin
                                NumberList := TeamPhone.Split(',');
                                foreach Number in NumberList do begin
                                    SMSDetail.APISMSSingalNo(Number, SMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                                end;
                            end;
                            SMSDetail.APISMSMultipleNo(CustomerPhone, SalespersonPhone, '', CustomerInfo."Mobile Phone No.", '', CustomerInfo."Alternate Phone No. 1", '', SMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');

                        END;
                        PreFeedText := FeedTxt;
                        PrevSMSBody := 'Dear' + ' ' +
                         FORMAT(Customername) + ' ' + 'Your Order with' + ' ' + FeedTxt + 'is Dispatched vide, Vehicle No.:-' +
                         FORMAT(ParaSaleShptsheader."Vehicle No.") + ' ' + 'Driver Mob No.:-' + FORMAT(ParaSaleShptsheader."Driver Mobile No.") + ',' + ' Sampoorna Feeds Pvt Ltd.';

                        // END;

                    END;
                UNTIL ParaSalesShptLine.NEXT = 0;
                IF SMSLine <> 0 THEN begin
                    //SMSfunctions.SendSMSByURL(PrevSMSBody);
                    // if CustomerPhone <> '' Then
                    //     WhatsAppSMS.SendSMS(CustomerPhone, PrevSMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                    Clear(NumberList);
                    if ShiptoPhone <> '' Then begin
                        NumberList := ShiptoPhone.Split(',');
                        foreach Number in NumberList do begin
                            SMSDetail.APISMSSingalNo(Number, PrevSMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                        end;
                    end;
                    // if SalespersonPhone <> '' Then
                    //     WhatsAppSMS.SendSMS(SalespersonPhone, PrevSMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                    if TeamPhone <> '' Then begin
                        NumberList := TeamPhone.Split(',');
                        foreach Number in NumberList do begin
                            SMSDetail.APISMSSingalNo(Number, PrevSMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');
                        end;
                    end;
                    SMSDetail.APISMSMultipleNo(CustomerPhone, SalespersonPhone, '', CustomerInfo."Mobile Phone No.", '', CustomerInfo."Alternate Phone No. 1", '', PrevSMSBody, '', ParaSaleShptsheader."Sell-to Customer No.", '1307165932646462646');

                end;
                // OTP := Random(999999);
                // OTPSMSBody := 'https://pgapi.vispl.in/fe/api/v1/multiSend?username=samprnpg.trans&password=' + SalesRece."SMS Password" + '&unicode=false&from=' + SalesRece."Sender ID" + '&to=' + PhoneNo + '&text=Dear Customer,' + ' ' +
                //  FORMAT(OTP) + ' ' + 'is your OTP for the Challan No.' + ' ' + ParaSaleShptsheader."No." + ',' + 'Please share the with Our Team and help desk No.' + ' Sampoorna Feeds Pvt Ltd.' + '&dltContentId=1307165932646462646&dltPrincipalEntityId=' + SalesRece."Entity ID";


            END;
        END;
    end;

    LOCAL procedure ReplaceString(String: Text; FindWhat: Text; ReplaceWith: Text) NewString: Text
    begin
        WHILE STRPOS(String, FindWhat) > 0 DO
            String := DELSTR(String, STRPOS(String, FindWhat)) + ReplaceWith + COPYSTR(String, STRPOS(String, FindWhat) + STRLEN(FindWhat));
        NewString := String;
    END;

    procedure SMSSendAtInvoice(VAR ParaSaleInvHeader: Record "Sales Invoice Header")
    var
        CustomerPhone: Text;
        ShiptoAdd: Record "Ship-to Address";
        TotalQuantity: Decimal;
        TotalAmount: Decimal;
        TotalUnitPrice: Decimal;
        TotalLineAmt: Decimal;
        SMSBody: Text[1024];
        CustomerInfo: Record Customer;
        ParaSalesInvLine: Record "Sales Invoice Line";
        Checkbool: Boolean;
        SMSfunctions: Codeunit "SMS functions";
        ComInfo: Record "Company Information";
        SalesRece: Record "Sales & Receivables Setup";
        WhatsAppSMS: Codeunit "WhatsApp Function";
        SMSDetail: Codeunit "SMS Details";
    begin

        ComInfo.Get;
        SalesRece.Get;
        CustomerPhone := '';

        IF CustomerInfo.GET(ParaSaleInvHeader."Sell-to Customer No.") THEN BEGIN
            IF CustomerInfo."Phone No." <> '' THEN BEGIN
                CustomerPhone := CustomerInfo."Phone No.";
            END ELSE BEGIN
                //ERROR('Customer Phone no. not found for %1', CustomerInfo.Name);
            END;
        END;

        TotalQuantity := 0;
        TotalAmount := 0;
        TotalUnitPrice := 0;
        TotalLineAmt := 0;

        ParaSalesInvLine.RESET;
        ParaSalesInvLine.SETRANGE("Document No.", ParaSaleInvHeader."No.");
        ParaSalesInvLine.SETFILTER(Quantity, '<>%1', 0);
        ParaSalesInvLine.SETRANGE("Shortcut Dimension 1 Code", 'CBF');
        IF ParaSalesInvLine.FINDSET THEN BEGIN
            REPEAT
                IF ParaSalesInvLine.Type = ParaSalesInvLine.Type::Item THEN BEGIN
                    TotalQuantity := ParaSalesInvLine.Quantity;
                    TotalUnitPrice := ParaSalesInvLine."Unit Price";
                    TotalLineAmt := ParaSalesInvLine."Line Amount";
                    IF CustomerPhone <> '' THEN BEGIN
                        if ComInfo.SFPLCompany in [ComInfo.SFPLCompany::Sampoorna] Then Begin
                            SMSBody := 'A/C' + ' ' + FORMAT(ParaSaleInvHeader."Sell-to Customer No.") + ' ' +
                                       'purchased live birds from SFPL against DC -' + FORMAT(ParaSaleInvHeader."External Document No.") + ', ' + FORMAT(TotalQuantity) + ' ' + FORMAT(ParaSalesInvLine."Unit of Measure Code") + ' ' + '(Rs ' + FORMAT(TotalUnitPrice) + '/' +
                                        FORMAT(ParaSalesInvLine."Unit of Measure Code") + ') Amount Rs. ' + FORMAT(TotalLineAmt) + ' and Birds - ' + FORMAT(ParaSalesInvLine."Alternate Quantity") + ' ' + FORMAT(ParaSalesInvLine."Alternate UOM") + ' ,Sampoorna Feeds Pvt Ltd.';
                            //WhatsAppSMS.SendSMS(CustomerPhone, SMSBody, '', CustomerInfo."No.", '1307165932681769800');

                            SMSDetail.APISMSMultipleNo(CustomerInfo."Phone No.", CustomerInfo."Mobile Phone No.", '', CustomerInfo."Alternate Phone No. 1", CustomerInfo."Alternate Phone No. 2", CustomerInfo."Alternate Phone No. 3", CustomerInfo."Alternate Phone No. 4", SMSBody, '', CustomerInfo."No.", '1307165932681769800'); // Airtel
                        End Else begin
                            SMSBody := 'A/C' + ' ' + FORMAT(ParaSaleInvHeader."Sell-to Customer No.") + ' ' +
                            'purchased live birds from SFPL against DC -' + FORMAT(ParaSaleInvHeader."External Document No.") + ', ' + FORMAT(TotalQuantity) + ' ' + FORMAT(ParaSalesInvLine."Unit of Measure Code") + ' ' + '(Rs ' + FORMAT(TotalUnitPrice) + '/' +
                            FORMAT(ParaSalesInvLine."Unit of Measure Code") + ') Amount Rs. ' + FORMAT(TotalLineAmt) + ' and Birds - ' + FORMAT(ParaSalesInvLine."Alternate Quantity") + ' ' + FORMAT(ParaSalesInvLine."Alternate UOM") + ' ,STAR FOODS.';
                            // WhatsAppSMS.SendSMS(CustomerPhone, SMSBody, '', CustomerInfo."No.", '1307173416167176171');
                            SMSDetail.APISMSMultipleNo(CustomerInfo."Phone No.", CustomerInfo."Mobile Phone No.", CustomerInfo."Alternate Phone No. 1", CustomerInfo."Alternate Phone No. 2", CustomerInfo."Alternate Phone No. 3", CustomerInfo."Alternate Phone No. 4", '', SMSBody, '', CustomerInfo."No.", '1307173416167176171');// Airtel
                        end;

                    END;
                END;
            UNTIL ParaSalesInvLine.NEXT = 0;
            //MESSAGE('Message has been sent to the customer');
        END;

    END;

    procedure OTPSMS(VAR ParaSaleShptsheader: Record "Sales Shipment Header")
    var
        CustomerPhone: Text[50];
        ShiptoAdd: Record "Ship-to Address";
        SalespersonRec: Record "Salesperson/Purchaser";
        SalespersonPhone: Text;
        TotalQuantity: Decimal;
        TotalAmount: Decimal;
        SMSBody: Text;
        CustomerInfo: Record Customer;
        ParaSalesShptLine: Record "Sales Shipment Line";
        PhoneNo: Text;
        PSShptLine: Record "Sales Shipment Line";
        FeedTxt: Text;
        SalesHeader: Record "Sales Header";
        SMSfunctions: Codeunit "SMS functions";
        SMSLine: Integer;
        PrevSMSBody: Text;
        PreFeedText: Text;
        Customer: Record Customer;
        SalesLine: Record "Sales Line";
        Customername: Text;
        Team: Record Team;
        SalesPersonTeam: Record "Team Salesperson";
        TeamPhone: Text;
        OTPSMSBody: Text;
        OTP: Integer;
        EntryNo: Integer;
        RandomOTP: Integer;
        SMSDetail: Codeunit "SMS Details";
        SalesandReceible: record "Sales & Receivables Setup";
        SalesShipment: record "Sales Shipment Header";
        SalesShipment2: record "Sales Shipment Header";
        WhatsAppSMS: Codeunit "WhatsApp Function";
    begin
        SalesandReceible.Get;
        Customer.Reset();
        Customer.SetFilter("Phone No.", '<>%1', '');
        Customer.SetRange("No.", ParaSaleShptsheader."Bill-to Customer No.");
        If Customer.FindFirst() Then begin
            PhoneNo := Customer."Phone No.";
            SalesShipment.Reset();
            SalesShipment.SetRange("No.", ParaSaleShptsheader."No.");
            SalesShipment.SetRange("Shortcut Dimension 1 Code", 'FEED');
            if SalesShipment.FindFirst() Then begin
                RandomOTP := Random(999999);
                SalesShipment.OTP := RandomOTP;
                SalesShipment."Phone No." := PhoneNo;
                SalesShipment."OTP Varified" := false;
                SalesShipment.SMS := 'Dear Customer,' + ' ' +
                 FORMAT(RandomOTP) + ' ' + 'is your OTP for Challan No.-' + ' ' + ParaSaleShptsheader."No." + '. ' + 'Please share with Our Team for confirmation of delivery. ' + ' Sampoorna Feeds Pvt. Ltd.';
                SalesShipment.Modify();
                Commit();
                //WhatsAppSMS.SendSMS(Customer."Phone No.", SalesShipment.SMS, '', Customer."No.", '1307172906240469364')
                SMSDetail.APISMSSingalNo(Customer."Phone No.", SalesShipment.SMS, '', Customer."No.", '1307172906240469364'); // Airtel

            end;
        end;
    end;

    procedure ReSendOTP(Var PostedSalesShipment: Record "Sales Shipment Header")
    var
        REODY: Text;
        Customer: Record Customer;
        SalesandReceible: Record "Sales & Receivables Setup";
        PhoneNo: Text;
        SMS: Codeunit "SMS functions";
        SMSDetail: Codeunit "SMS Details";
        SalesShipment: Record "Sales Shipment Header";
        WhatsAppSMS: Codeunit "WhatsApp Function";
    Begin

        SalesandReceible.Get;
        Customer.Reset();
        Customer.SetFilter("Phone No.", '<>%1', '');
        Customer.SetRange("No.", PostedSalesShipment."Bill-to Customer No.");
        If Customer.FindFirst() Then begin
            PhoneNo := Customer."Phone No.";
            SalesShipment.Reset();
            SalesShipment.SetRange("No.", PostedSalesShipment."No.");
            SalesShipment.SetRange("OTP Varified at", 0DT);
            If SalesShipment.FindFirst() then begin
                //REODY := 'https://pgapi.vispl.in/fe/api/v1/multiSend?username=' + SalesandReceible."SMS User" + '&password=' + SalesandReceible."SMS Password" + '&unicode=false&from=SFPLCO&to=' + PhoneNo + '&text=' + SalesShipment.SMS + '&dltContentId=1307172906240469364&dltPrincipalEntityId=' + SalesandReceible."Entity ID";
                //SMS.SendSMSByURL(REODY);
                //WhatsAppSMS.SendSMS(Customer."Phone No.", SalesShipment.SMS, '', Customer."No.", '1307172906240469364')
                SMSDetail.APISMSSingalNo(Customer."Phone No.", SalesShipment.SMS, '', Customer."No.", '1307172906240469364');// Airtel
            end;
        end;
    End;



    procedure InvoiceSendonWhatsapp(No: Code[20]; "Billtocode": Code[10])
    var
        // OStream: 
        Cust: Record Customer;
        SalesInvoiceHeader: Record "Sales Invoice Header";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        SalesInvoiceReport: Report "Sales Invoice New-GST";
        Outstr: OutStream;
        FileManagement: Codeunit "File Management";
        WebMessageBody: Text;
        WhatsApp: Codeunit "WhatsApp Function";
        PhoneNo: text;
        FileName: Text;
        CustLedger: Record "Cust. Ledger Entry";
        EmailBody: Text;
        SMTPMail: Codeunit "Email Message";
        Email: Codeunit Email;
        Instr: InStream;
        Salesperson: Record "Salesperson/Purchaser";
    begin

        Clear(FileName);
        Clear(FileManagement);
        FileName := 'D:\Whatsapp\' + 'Invoice' + No + '.pdf';
        Clear(Outstr);
        SalesInvoiceHeader.Reset();
        SalesInvoiceHeader.SetRange("No.", No);
        SalesInvoiceHeader.SetRange("Bill-to Customer No.", Billtocode);
        If SalesInvoiceHeader.FindFirst() Then begin
            // RecRef.GetTable(SalesInvoiceHeader);
            // TempBlob.CreateOutStream(Outstr);
            // Report.SaveAs(Report::"Sales Invoice New-GST", '', ReportFormat::Pdf, Outstr, RecRef);
            // FileManagement.BLOBExportToServerFile(TempBlob, FileName);
            Cust.Get(SalesInvoiceHeader."Bill-to Customer No.");
            if Cust."WhatsApp Mobile No." <> '' then
                PhoneNo := Cust."WhatsApp Mobile No."
            else
                PhoneNo := Cust."Phone No.";
            //if SalesInvoiceHeader."Shortcut Dimension 1 Code" <> 'CATTLE' Then
            //WhatsApp.WhatsAppAPI(WhatsApp.WhatsAppInvoice(PhoneNo, Cust.Name, SalesInvoiceHeader."Posting Date", SalesInvoiceHeader."No.", 'https://sfplwhatsapp.sampoornafeeds.in/' + 'Invoice' + No + '.pdf', No, 'salesinvoice'));
            WhatsApp.AirtelWhatssAppAPI(WhatsApp.WhatsAppInvoice(PhoneNo, Cust.Name, SalesInvoiceHeader."Posting Date", SalesInvoiceHeader."No.", 'https://sfplwhatsapp.sampoornafeeds.in/' + 'Invoice' + No + '.pdf', No, '01khb73yhvgxvmm1bg40hy7v2j'));



        end;
    end;

    procedure ApplyEntry(Var Rec: Record "Sales Header")
    var
        SalesHeader: Record "Sales Header";
        CustLedgEntry: Record "Cust. Ledger Entry";
        ApplyCustEntries: Page "Apply Customer Entries";
        BilToCustNo: Code[20];
        OK: Boolean;

        Text000: Label 'You must specify %1 or %2.';
    begin
        SalesHeader.Copy(Rec);
        with SalesHeader do begin
            BilToCustNo := "Bill-to Customer No.";
            CustLedgEntry.SetCurrentKey("Customer No.", Open);
            CustLedgEntry.SetRange("Customer No.", BilToCustNo);
            CustLedgEntry.SetRange("Document Type", CustLedgEntry."Document Type"::Payment);
            CustLedgEntry.SetRange(Open, true);
            //OnRunOnAfterFilterCustLedgEntry(CustLedgEntry, SalesHeader);
            if "Applies-to ID" = '' then
                "Applies-to ID" := "No.";
            if "Applies-to ID" = '' then
                Error(
                  Text000,
                  FieldCaption("No."), FieldCaption("Applies-to ID"));
            ApplyCustEntries.SetSales(SalesHeader, CustLedgEntry, FieldNo("Applies-to ID"));
            ApplyCustEntries.SetRecord(CustLedgEntry);
            ApplyCustEntries.SetTableView(CustLedgEntry);
            ApplyCustEntries.LookupMode(true);
            OK := ApplyCustEntries.RunModal() = ACTION::LookupOK;
            Clear(ApplyCustEntries);
            if not OK then
                exit;
            CustLedgEntry.Reset();
            CustLedgEntry.SetCurrentKey("Customer No.", Open);
            CustLedgEntry.SetRange("Customer No.", BilToCustNo);
            CustLedgEntry.SetRange(Open, true);
            CustLedgEntry.SetRange("Applies-to ID", "Applies-to ID");
            //OnRunOnBeforeCustLedgEntryFindFirst(CustLedgEntry);
            if CustLedgEntry.FindFirst() then begin
                "Applies-to Doc. Type" := "Applies-to Doc. Type"::" ";
                "Applies-to Doc. No." := '';
            end else
                "Applies-to ID" := '';

            Modify();
        end;
    end;

    local procedure CheckSalesShptLine(SalesShipmentLine2: Record "Sales Shipment Line")
    var
        TempItemLedgerEntry: Record "Item Ledger Entry" temporary;
        IsHandled: Boolean;
        SkipTestFields: Boolean;
        SkipUndoPosting: Boolean;
        SkipUndoInitPostATO: Boolean;
        UndoPostingManagement: Codeunit "Undo Posting Management";
        Text005: Label 'This shipment has already been invoiced. Undo Shipment can be applied only to posted, but not invoiced shipments.';
    begin
        // IsHandled := false;
        // OnBeforeCheckSalesShptLine(SalesShipmentLine2, IsHandled, SkipTestFields, SkipUndoPosting, SkipUndoInitPostATO);
        // if not IsHandled then
        with SalesShipmentLine2 do begin
            if not SkipTestFields then begin
                if Correction then
                    Error(AlreadyReversedErr);

                // IsHandled := false;
                // OnCheckSalesShptLineOnBeforeHasInvoicedNotReturnedQuantity(SalesShipmentLine2, IsHandled);
                // if not IsHandled then
                if "Qty. Shipped Not Invoiced" <> Quantity then
                    if HasInvoicedNotReturnedQuantity(SalesShipmentLine2) then
                        Error(Text005);
            end;
            if Type = Type::Item then begin
                if not SkipTestFields then
                    TestField("Drop Shipment", false);

                if not SkipUndoPosting then begin
                    UndoPostingManagement.TestSalesShptLine(SalesShipmentLine2);

                    // IsHandled := false;
                    // OnCheckSalesShptLineOnBeforeCollectItemLedgEntries(SalesShipmentLine2, TempItemLedgerEntry, IsHandled);
                    // if not IsHandled then
                    UndoPostingManagement.CollectItemLedgEntries(
                        TempItemLedgerEntry, DATABASE::"Sales Shipment Line", "Document No.", "Line No.", "Quantity (Base)", "Item Shpt. Entry No.");
                    UndoPostingManagement.CheckItemLedgEntries(TempItemLedgerEntry, "Line No.", "Qty. Shipped Not Invoiced" <> Quantity);
                end;
                if not SkipUndoInitPostATO then
                    UndoInitPostATO(SalesShipmentLine2);
            end;
        end;

        //OnAfterCheckSalesShptLine(SalesShipmentLine2, TempItemLedgerEntry);
    end;

    local procedure HasInvoicedNotReturnedQuantity(SalesShipmentLine2: Record "Sales Shipment Line"): Boolean
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReturnedInvoicedItemLedgerEntry: Record "Item Ledger Entry";
        ItemApplicationEntry: Record "Item Application Entry";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        InvoicedQuantity: Decimal;
        ReturnedInvoicedQuantity: Decimal;

    begin
        if SalesShipmentLine2.Type = SalesShipmentLine2.Type::Item then begin
            ItemLedgerEntry.SetRange("Document Type", ItemLedgerEntry."Document Type"::"Sales Shipment");
            ItemLedgerEntry.SetRange("Document No.", SalesShipmentLine2."Document No.");
            ItemLedgerEntry.SetRange("Document Line No.", SalesShipmentLine2."Line No.");
            ItemLedgerEntry.FindSet();
            repeat
                InvoicedQuantity += ItemLedgerEntry."Invoiced Quantity";
                if ItemApplicationEntry.AppliedInbndEntryExists(ItemLedgerEntry."Entry No.", false) then
                    repeat
                        if ItemApplicationEntry."Item Ledger Entry No." = ItemApplicationEntry."Inbound Item Entry No." then begin
                            ReturnedInvoicedItemLedgerEntry.Get(ItemApplicationEntry."Item Ledger Entry No.");
                            if SalesIsCancelled(ReturnedInvoicedItemLedgerEntry) then
                                ReturnedInvoicedQuantity += ReturnedInvoicedItemLedgerEntry."Invoiced Quantity";
                        end;
                    until ItemApplicationEntry.Next() = 0;
            until ItemLedgerEntry.Next() = 0;
            exit(InvoicedQuantity + ReturnedInvoicedQuantity <> 0);
        end else begin
            SalesInvoiceLine.SetRange("Order No.", SalesShipmentLine2."Order No.");
            SalesInvoiceLine.SetRange("Order Line No.", SalesShipmentLine2."Order Line No.");
            if SalesInvoiceLine.FindSet() then
                repeat
                    SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.");
                    if not IsSalesInvoiceCancelled(SalesInvoiceHeader) then
                        exit(true);
                until SalesInvoiceLine.Next() = 0;

            exit(false);
        end;
    end;

    local procedure IsSalesInvoiceCancelled(var SalesInvoiceHeader: Record "Sales Invoice Header") Result: Boolean
    begin
        SalesInvoiceHeader.CalcFields(Cancelled);
        Result := SalesInvoiceHeader.Cancelled;

        //OnAfterIsSalesInvoiceCancelled(SalesInvoiceHeader, Result);
    end;

    local procedure SalesIsCancelled(ItemLedgerEntry: Record "Item Ledger Entry"): Boolean
    var
        CancelledDocument: Record "Cancelled Document";
        ReturnReceiptHeader: Record "Return Receipt Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
    begin
        case ItemLedgerEntry."Document Type" of
            ItemLedgerEntry."Document Type"::"Sales Return Receipt":
                begin
                    ReturnReceiptHeader.Get(ItemLedgerEntry."Document No.");
                    if ReturnReceiptHeader."Applies-to Doc. Type" = ReturnReceiptHeader."Applies-to Doc. Type"::Invoice then
                        exit(CancelledDocument.Get(Database::"Sales Invoice Header", ReturnReceiptHeader."Applies-to Doc. No."));
                end;
            ItemLedgerEntry."Document Type"::"Sales Credit Memo":
                begin
                    SalesCrMemoHeader.Get(ItemLedgerEntry."Document No.");
                    if SalesCrMemoHeader."Applies-to Doc. Type" = SalesCrMemoHeader."Applies-to Doc. Type"::Invoice then
                        exit(CancelledDocument.Get(Database::"Sales Invoice Header", SalesCrMemoHeader."Applies-to Doc. No."));
                end;
        end;

        exit(false);
    end;

    local procedure UndoInitPostATO(var SalesShipmentLine2: Record "Sales Shipment Line")
    var
        PostedAssemblyHeader: Record "Posted Assembly Header";
        AssemblyPost: Codeunit "Assembly-Post";
    begin
        if SalesShipmentLine2.AsmToShipmentExists(PostedAssemblyHeader) then begin
            //OpenATOProgressWindow(Text055, SalesShipmentLine2, PostedAssemblyHeader);
            AssemblyPost.UndoInitPostATO(PostedAssemblyHeader);
            //ATOWindowDialog.Close();
        end;
    end;

    local procedure PostItemJnlLine(SalesShipmentLine2: Record "Sales Shipment Line"; var DocLineNo: Integer): Integer
    var
        ItemJournalLine: Record "Item Journal Line";
        SalesLine: Record "Sales Line";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SourceCodeSetup: Record "Source Code Setup";
        TempApplyToItemLedgerEntry: Record "Item Ledger Entry" temporary;
        ItemLedgerEntryNotInvoiced: Record "Item Ledger Entry";
        ItemLedgEntryNo: Integer;
        RemQtyBase: Decimal;
        IsHandled: Boolean;
        UndoSptLine: Codeunit "Undo Sales Shipment Line";
        UndoPostingManagement: Codeunit "Undo Posting Management";
        WhseUndoQuantity: Codeunit "Whse. Undo Quantity";
    begin
        // IsHandled := false;
        // OnBeforePostItemJnlLine(
        //     SalesShipmentLine2, DocLineNo, ItemLedgEntryNo, IsHandled, TempGlobalItemLedgerEntry, TempGlobalItemEntryRelation, TempWarehouseJournalLine, NextLineNo);
        // if IsHandled then
        //     exit(ItemLedgEntryNo);

        with SalesShipmentLine2 do begin
            DocLineNo := UndoSptLine.GetCorrectionLineNo(SalesShipmentLine2);

            SourceCodeSetup.Get();
            SalesShipmentHeader.Get("Document No.");

            ItemJournalLine.Init();
            ItemJournalLine."Entry Type" := ItemJournalLine."Entry Type"::Sale;
            ItemJournalLine."Item No." := "No.";
            ItemJournalLine."Posting Date" := SalesShipmentHeader."Posting Date";
            ItemJournalLine."Document No." := "Document No.";
            ItemJournalLine."Document Line No." := DocLineNo;
            ItemJournalLine."Gen. Bus. Posting Group" := "Gen. Bus. Posting Group";
            ItemJournalLine."Gen. Prod. Posting Group" := "Gen. Prod. Posting Group";
            ItemJournalLine."Location Code" := "Location Code";
            ItemJournalLine."Source Code" := SourceCodeSetup.Sales;
            ItemJournalLine.Correction := true;
            ItemJournalLine."Variant Code" := "Variant Code";
            ItemJournalLine."Bin Code" := "Bin Code";
            ItemJournalLine."Document Date" := SalesShipmentHeader."Document Date";

            //OnAfterCopyItemJnlLineFromSalesShpt(ItemJournalLine, SalesShipmentHeader, SalesShipmentLine2, TempWarehouseJournalLine, WhseUndoQuantity);

            UndoPostingManagement.CollectItemLedgEntries(
                TempApplyToItemLedgerEntry, DATABASE::"Sales Shipment Line", "Document No.", "Line No.", "Quantity (Base)", "Item Shpt. Entry No.");

            if ("Qty. Shipped Not Invoiced" = Quantity) or
               not UndoPostingManagement.AreAllItemEntriesCompletelyInvoiced(TempApplyToItemLedgerEntry)
            then
                WhseUndoQuantity.InsertTempWhseJnlLine(
                    ItemJournalLine,
                    DATABASE::"Sales Line", SalesLine."Document Type"::Order.AsInteger(), "Order No.", "Order Line No.",
                    TempWarehouseJournalLine."Reference Document"::"Posted Shipment".AsInteger(), TempWarehouseJournalLine, NextLineNo);
            //OnPostItemJnlLineOnAfterInsertTempWhseJnlLine(SalesShipmentLine2, ItemJournalLine, TempWarehouseJournalLine, NextLineNo);

            if UndoSalesShipmentLine.GetInvoicedShptEntries(SalesShipmentLine2, ItemLedgerEntryNotInvoiced) then begin
                RemQtyBase := -("Quantity (Base)" - "Qty. Invoiced (Base)");
                //OnPostItemJnlLineOnAfterCalcRemQtyBase(RemQtyBase, ItemJournalLine, SalesShipmentLine2, ItemLedgerEntryNotInvoiced);
                repeat
                    ItemJournalLine."Applies-to Entry" := ItemLedgerEntryNotInvoiced."Entry No.";
                    ItemJournalLine.Quantity := ItemLedgerEntryNotInvoiced.Quantity;
                    ItemJournalLine."Quantity (Base)" := ItemLedgerEntryNotInvoiced.Quantity;
                    IsHandled := false;
                    // OnPostItemJnlLineOnBeforeRunItemJnlPostLine(ItemJournalLine, ItemLedgerEntryNotInvoiced, SalesShipmentLine2, SalesShipmentHeader, IsHandled);
                    // if not IsHandled then
                    ItemJnlPostLine.Run(ItemJournalLine);
                    //OnPostItemJnlLineOnAfterRunItemJnlPostLine(ItemJournalLine);
                    RemQtyBase -= ItemJournalLine.Quantity;
                    if ItemLedgerEntryNotInvoiced.Next() = 0 then;
                until (RemQtyBase = 0);
                //OnItemJnlPostLineOnAfterGetInvoicedShptEntriesOnBeforeExit(ItemJournalLine, SalesShipmentLine2);
                exit(ItemJournalLine."Item Shpt. Entry No.");
            end;

            UndoPostingManagement.PostItemJnlLineAppliedToList(
                ItemJournalLine, TempApplyToItemLedgerEntry, Quantity - "Quantity Invoiced", "Quantity (Base)" - "Qty. Invoiced (Base)", TempGlobalItemLedgerEntry, TempGlobalItemEntryRelation, "Qty. Shipped Not Invoiced" <> Quantity);

            //OnAfterPostItemJnlLine(ItemJournalLine, SalesShipmentLine2);
            exit(0); // "Item Shpt. Entry No."
        end;
    end;

    local procedure InsertNewShipmentLine(OldSalesShipmentLine: Record "Sales Shipment Line"; ItemShptEntryNo: Integer; DocLineNo: Integer)
    var
        NewSalesShipmentLine: Record "Sales Shipment Line";
    begin
        with OldSalesShipmentLine do begin
            NewSalesShipmentLine.Init();
            NewSalesShipmentLine.Copy(OldSalesShipmentLine);
            NewSalesShipmentLine."Line No." := DocLineNo;
            NewSalesShipmentLine."Appl.-from Item Entry" := "Item Shpt. Entry No.";
            NewSalesShipmentLine."Item Shpt. Entry No." := ItemShptEntryNo;
            NewSalesShipmentLine.Quantity := -Quantity;
            NewSalesShipmentLine."Qty. Shipped Not Invoiced" := 0;
            NewSalesShipmentLine."Quantity (Base)" := -"Quantity (Base)";
            NewSalesShipmentLine."Quantity Invoiced" := NewSalesShipmentLine.Quantity;
            NewSalesShipmentLine."Qty. Invoiced (Base)" := NewSalesShipmentLine."Quantity (Base)";
            NewSalesShipmentLine.Correction := true;
            NewSalesShipmentLine."Dimension Set ID" := "Dimension Set ID";
            //OnBeforeNewSalesShptLineInsert(NewSalesShipmentLine, OldSalesShipmentLine);
            NewSalesShipmentLine.Insert();
            //OnAfterNewSalesShptLineInsert(NewSalesShipmentLine, OldSalesShipmentLine);

            InsertItemEntryRelation(TempGlobalItemEntryRelation, NewSalesShipmentLine);
        end;
    end;

    procedure InsertItemEntryRelation(var TempItemEntryRelation: Record "Item Entry Relation" temporary; NewSalesShipmentLine: Record "Sales Shipment Line")
    var
        ItemEntryRelation: Record "Item Entry Relation";
    begin
        if TempItemEntryRelation.Find('-') then
            repeat
                ItemEntryRelation := TempItemEntryRelation;
                ItemEntryRelation.TransferFieldsSalesShptLine(NewSalesShipmentLine);
                ItemEntryRelation.Insert();
            until TempItemEntryRelation.Next() = 0;
    end;


    procedure UndoShipment(RecSalesShipmentLine: Record "Sales Shipment Line")
    var

        PostedWhseShipmentLine: Record "Posted Whse. Shipment Line";
        SalesLine: Record "Sales Line";
        ServiceItem: Record "Service Item";
        WhseJnlRegisterLine: Codeunit "Whse. Jnl.-Register Line";
        WindowDialog: Dialog;
        ItemShptEntryNo: Integer;
        DocLineNo: Integer;
        DeleteServItems: Boolean;
        PostedWhseShptLineFound: Boolean;
        IsHandled: Boolean;
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        SalesShipmentLine: Record "Sales Shipment Line";

        WhseUndoQuantity: Codeunit "Whse. Undo Quantity";
    begin
        SalesShipmentLine.reset();
        SalesShipmentLine.setRange("Document No.", RecSalesShipmentLine."Document No.");
        SalesShipmentLine.setRange("Line No.", RecSalesShipmentLine."Line No.");
        if SalesShipmentLine.findFirst() then;
        with SalesShipmentLine do begin
            Clear(ItemJnlPostLine);
            SetCurrentKey("Item Shpt. Entry No.");
            SetFilter(Quantity, '<>0');
            SetRange(Correction, false);
            //OnCodeOnAfterSalesShptLineSetFilters(SalesShipmentLine);
            if IsEmpty() then
                Error(AlreadyReversedErr);
            FindFirst();
            repeat
                // if not HideDialog then
                //     WindowDialog.Open(Text003);
                CheckSalesShptLine(SalesShipmentLine);
            until Next() = 0;

            ServiceItem.SetCurrentKey("Sales/Serv. Shpt. Document No.");
            ServiceItem.SetRange("Sales/Serv. Shpt. Document No.", "Document No.");
            if ServiceItem.FindFirst() then
                DeleteServItems := True; //ShouldDeleteServItems(ServiceItem);

            Find('-');
            repeat
                //OnCodeOnBeforeUndoLoop(SalesShipmentLine);
                TempGlobalItemLedgerEntry.Reset();
                if not TempGlobalItemLedgerEntry.IsEmpty() then
                    TempGlobalItemLedgerEntry.DeleteAll();
                TempGlobalItemEntryRelation.Reset();
                if not TempGlobalItemEntryRelation.IsEmpty() then
                    TempGlobalItemEntryRelation.DeleteAll();

                // if not HideDialog then
                //     WindowDialog.Open(Text001);

                // IsHandled := false;
                // OnCodeOnBeforeProcessItemShptEntry(ItemShptEntryNo, DocLineNo, SalesShipmentLine, IsHandled);
                // If not IsHandled then
                if Type = Type::Item then begin
                    PostedWhseShptLineFound :=
                    WhseUndoQuantity.FindPostedWhseShptLine(
                        PostedWhseShipmentLine, DATABASE::"Sales Shipment Line", "Document No.",
                        DATABASE::"Sales Line", SalesLine."Document Type"::Order.AsInteger(), "Order No.", "Order Line No.");

                    Clear(ItemJnlPostLine);
                    ItemShptEntryNo := PostItemJnlLine(SalesShipmentLine, DocLineNo);
                end else
                    DocLineNo := UndoSalesShipmentLine.GetCorrectionLineNo(SalesShipmentLine);

                InsertNewShipmentLine(SalesShipmentLine, ItemShptEntryNo, DocLineNo);
                //OnAfterInsertNewShipmentLine(SalesShipmentLine, PostedWhseShipmentLine, PostedWhseShptLineFound, DocLineNo, ItemShptEntryNo);

                if PostedWhseShptLineFound then
                    WhseUndoQuantity.UndoPostedWhseShptLine(PostedWhseShipmentLine);

                TempWarehouseJournalLine.SetRange("Source Line No.", "Line No.");
                WhseUndoQuantity.PostTempWhseJnlLineCache(TempWarehouseJournalLine, WhseJnlRegisterLine);

                //UndoPostATO(SalesShipmentLine, WhseJnlRegisterLine);

                UndoSalesShipmentLine.UpdateOrderLine(SalesShipmentLine);
                if PostedWhseShptLineFound then
                    WhseUndoQuantity.UpdateShptSourceDocLines(PostedWhseShipmentLine);

                if ("Blanket Order No." <> '') and ("Blanket Order Line No." <> 0) then
                    UndoSalesShipmentLine.UpdateBlanketOrder(SalesShipmentLine);

                // if DeleteServItems then
                //     DeleteSalesShptLineServItems(SalesShipmentLine);

                "Quantity Invoiced" := Quantity;
                "Qty. Invoiced (Base)" := "Quantity (Base)";
                "Qty. Shipped Not Invoiced" := 0;
                Correction := true;

                //OnBeforeSalesShptLineModify(SalesShipmentLine);
                Modify();
            //OnAfterSalesShptLineModify(SalesShipmentLine, DocLineNo);

            //UndoFinalizePostATO(SalesShipmentLine);
            until Next() = 0;

            MakeInventoryAdjustment();
        end;

        //OnAfterCode(SalesShipmentLine);
    end;

    local procedure ClearBuffer()
    begin
        ClearAll();
        TempTransferBufferStage.DeleteAll();
        TempTransferBufferFinal.DeleteAll();
        TempGSTPostingBufferStage.DeleteAll();
        TempGSTPostingBufferFinal.DeleteAll();
        TempItemJnlLine.DeleteAll();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnAfterInsertTransRcptLine', '', false, false)]
    local procedure CeateGSTLedgerEntry(TransLine: Record "Transfer Line"; var TransRcptLine: Record "Transfer Receipt Line")
    var
        TransferHeader: Record "Transfer Header";
        DocTransferType: Enum "Doc Transfer Type";
    begin
        ItemJournalCustom := 0;
        ItemLedgerEntryNo := 0;
        TransferHeader.Get(TransLine."Document No.");
        InsertDetailedGSTLedgEntryTransfer(TransLine,
            TransferHeader,
            TransRcptLine."Document No.",
            GenJnlPostLine.GetNextTransactionNo(),
            DocTransferType::"Transfer Receipt");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnAfterTransLineUpdateQtyReceived', '', false, false)]
    local procedure CreateGSTTrackingEntry(var TransferLine: Record "Transfer Line")
    var
        TransferHeader: Record "Transfer Header";
        OriginalDocType: Enum "Original Doc Type";
    begin
        ItemJournalCustom := 0;
        ItemLedgerEntryNo := 0;
        TransferHeader.Get(TransferLine."Document No.");
        UpdateGSTTrackingEntryFromTransferOrder(TransReceiptHeaderNo,
            TransferLine."Item No.",
            TransferLine."Line No.",
            OriginalDocType::"Transfer Receipt");
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnAfterPostItemJnlLine', '', false, false)]
    local procedure InsertTransferBuffer(var TransLine3: Record "Transfer Line"; var TransRcptHeader2: Record "Transfer Receipt Header"; var TransRcptLine2: Record "Transfer Receipt Line"; var ItemJnlPostLine: Codeunit "Item Jnl.-Post Line")
    begin
        FillTransferBuffer(TransLine3);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnCheckTransLine', '', false, false)]
    local procedure FillBuffers(TransferLine: Record "Transfer Line")
    var
        GSTGroup: Record "GST Group";
        DocTransactionType: Enum "Transaction Type Enum";
        DocumentType: Enum "Document Type Enum";
        IsHandled: Boolean;
    begin


        if TransferLine.Quantity <> 0 then
            GSTAmountLoaded := Abs(
                RoundTotalGSTAmountLoadedQtyFactor(
                DocTransactionType::Transfer,
                DocumentType::Quote,
                TransferLine."Document No.",
                TransferLine."Line No.",
                TransferLine."Qty. to Receive" / TransferLine.Quantity,
            '')
        );

        if GSTGroup.Get(TransferLine."GST Group Code") and (GSTGroup."GST Group Type" <> GSTGroup."GST Group Type"::Goods) then
            Error(GSTGroupServiceErr);

        if (TransferLine."Qty. to Receive" <> 0) and (GetGSTAmount(TransferLine.RecordId) = 0) then
            FillGSTPostingBuffer(TransferLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeTransferOrderPostReceipt', '', false, false)]
    local procedure CheckGSTValidation(var TransferHeader: Record "Transfer Header")
    begin
        ClearBuffer();
        CheckValidations(TransferHeader);
        GSTBaseValidation.CheckGSTAccountingPeriod(TransferHeader."Posting Date", false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeTransRcptHeaderInsert', '', false, false)]
    local procedure FillGSTLedgerBuffer(TransferHeader: Record "Transfer Header")
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
    begin
        ClearBuffer();
        DetailedGSTEntryBuffer.SetRange("Document Type", DetailedGSTEntryBuffer."Document Type"::Quote);
        DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
        DetailedGSTEntryBuffer.SetRange("Document No.", TransferHeader."No.");
        if DetailedGSTEntryBuffer.FindFirst() then
            DetailedGSTEntryBuffer.DeleteAll(true);

        FillDetailLedgBufferTransfer(TransferHeader."No.");
        GetCustomDutyAmount(TransferHeader."No.");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeDeleteOneTransferHeader', '', false, false)]
    local procedure PostEntries(TransferHeader: Record "Transfer Header"; TransferReceiptHeader: Record "Transfer Receipt Header")
    var
        Item: Record Item;
        CustomDutyBase: Boolean;
        IsHandled: Boolean;
    begin
        FirstExecution := true;
        if TransReceiptHeaderNo <> TransferReceiptHeader."No." then
            TransReceiptHeaderNo := TransferReceiptHeader."No.";



        //Post GL Entries
        TempTransferBufferfinal.Reset();
        if TempTransferBufferfinal.FindLast() then
            repeat

                GSTPostingBufferforTransferDocument(CustomDutyBase, TransferHeader);

            until TempTransferBufferfinal.Next(-1) = 0;
        TempTransferBufferfinal.DeleteAll();
    end;

    local procedure PostGLEntries(var TransferHeader: Record "Transfer Header"; TempTransferBufferfinal: Record "Transfer Buffer"; TransferReceiptHeader: Record "Transfer Receipt Header")
    var
        InventoryPostingSetup: Record "Inventory Posting Setup";
        Item: Record Item;
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();
        InventoryPostingSetup.Get(TransferHeader."In-Transit Code", TempTransferBufferfinal."Inventory Posting Group");
        if Item.Get(TempTransferBufferfinal."Item No.") and (item."HSN/SAC Code" <> '') then
            InventoryPostingSetup.TestField("Unrealized Profit Account");

        GenJnlLine.Init();
        GenJnlLine."Posting Date" := TransferHeader."Posting Date";
        GenJnlLine."Document Date" := TransferHeader."Posting Date";
        GenJnlLine."Document No." := TransferReceiptHeader."No.";
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        if (TempTransferBufferfinal."Gen. Bus. Posting Group" <> '') then
            GenJnlLine."Account No." := GetIGSTImportAccountNo(TempTransferBufferfinal."Location Code")
        else
            GenJnlLine."Account No." := InventoryPostingSetup."Unrealized Profit Account";

        GenJnlLine."System-Created Entry" := TempTransferBufferfinal."System-Created Entry";
        GenJnlLine."Gen. Bus. Posting Group" := TempTransferBufferfinal."Gen. Bus. Posting Group";
        GenJnlLine."Gen. Prod. Posting Group" := TempTransferBufferfinal."Gen. Prod. Posting Group";
        if (TempTransferBufferfinal."Gen. Bus. Posting Group" <> '') then
            GenJnlLine.Amount := (TempTransferBufferfinal."GST Amount")
        else
            GenJnlLine.Amount := -(TempTransferBufferfinal.Amount + TempTransferBufferfinal."Charges Amount" + TempTransferBufferfinal."GST Amount");

        GenJnlLine.Quantity := TempTransferBufferfinal.Quantity;
        GenJnlLine."Source Code" := SourcecodeSetup.Transfer;
        GenJnlLine."Shortcut Dimension 1 Code" := TempTransferBufferfinal."Global Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := TempTransferBufferfinal."Global Dimension 2 Code";
        GenJnlLine."Dimension Set ID" := TempTransferBufferfinal."Dimension Set ID";
        GenJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, TransferReceiptHeader."No.");
        if (GenJnlLine.Amount <> 0) then
            RunGenJnlPostLine(GenJnlLine);
    end;

    local procedure PostInventoryEntries(var TransferHeader: Record "Transfer Header"; TempTransferBufferfinal: Record "Transfer Buffer")
    var
        GeneralPostingSetup: Record "General Posting Setup";
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();
        GeneralPostingSetup.Get(TempTransferBufferfinal."Gen. Bus. Posting Group", TempTransferBufferfinal."Gen. Prod. Posting Group");
        GeneralPostingSetup.TestField("Inventory Adjmt. Account");

        GenJnlLine.Init();
        GenJnlLine."Posting Date" := TransferHeader."Posting Date";
        GenJnlLine."Document Date" := TransferHeader."Posting Date";
        GenJnlLine."Document No." := TransReceiptHeaderNo;
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        if (TempTransferBufferfinal."Gen. Bus. Posting Group" <> '') then
            GenJnlLine."Account No." := TempTransferBufferfinal."G/L Account"
        else
            GenJnlLine."Account No." := GeneralPostingSetup."Inventory Adjmt. Account";

        GenJnlLine."System-Created Entry" := TempTransferBufferfinal."System-Created Entry";
        GenJnlLine.Amount := Abs(TempTransferBufferfinal."Amount Loaded on Inventory" + TempTransferBufferfinal."GST Amount Loaded on Inventory");
        GenJnlLine."Gen. Bus. Posting Group" := TempTransferBufferfinal."Gen. Bus. Posting Group";
        GenJnlLine."Gen. Prod. Posting Group" := TempTransferBufferfinal."Gen. Prod. Posting Group";
        GenJnlLine."Source Code" := SourcecodeSetup.Transfer;
        GenJnlLine."Shortcut Dimension 1 Code" := TempTransferBufferfinal."Global Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := TempTransferBufferfinal."Global Dimension 2 Code";
        GenJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, TransReceiptHeaderNo);
        if (GenJnlLine.Amount <> 0) then
            RunGenJnlPostLine(GenJnlLine);
    end;

    local procedure PostUnrealizedProfitAccountEntries(TransferHeader: Record "Transfer Header"; TempTransferBufferfinal: Record "Transfer Buffer"; TransferReceiptHeader: Record "Transfer Receipt Header")
    var
        InventoryPostingSetup: Record "Inventory Posting Setup";
        SourceCodeSetup: Record "Source Code Setup";
        Item: Record Item;
    begin
        SourceCodeSetup.Get();
        InventoryPostingSetup.Get(TransferHeader."Transfer-to Code", TempTransferBufferfinal."Inventory Posting Group");
        if Item.Get(TempTransferBufferFinal."Item No.") and (item."HSN/SAC Code" <> '') then
            InventoryPostingSetup.TestField("Unrealized Profit Account");

        GenJnlLine.Init();
        GenJnlLine."Posting Date" := TransferHeader."Posting Date";
        GenJnlLine."Document Date" := TransferHeader."Posting Date";
        GenJnlLine."Document No." := TransferReceiptHeader."No.";
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        if (TempTransferBufferfinal."Gen. Bus. Posting Group" <> '') then
            GenJnlLine."Account No." := GetIGSTImportAccountNo(TempTransferBufferfinal."Location Code")
        else
            GenJnlLine."Account No." := InventoryPostingSetup."Unrealized Profit Account";

        if (TempTransferBufferfinal."Gen. Bus. Posting Group" <> '') then
            GenJnlLine.Amount := (TempTransferBufferfinal.Amount)
        else
            GenJnlLine.Amount := TempTransferBufferfinal.Amount;

        GenJnlLine."System-Created Entry" := TempTransferBufferfinal."System-Created Entry";
        GenJnlLine."Source Code" := SourceCodeSetup.Transfer;
        GenJnlLine."Gen. Bus. Posting Group" := TempTransferBufferfinal."Gen. Bus. Posting Group";
        GenJnlLine."Gen. Prod. Posting Group" := TempTransferBufferfinal."Gen. Prod. Posting Group";
        GenJnlLine."Shortcut Dimension 1 Code" := TempTransferBufferfinal."Global Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := TempTransferBufferfinal."Global Dimension 2 Code";
        GenJnlLine."Dimension Set ID" := TempTransferBufferfinal."Dimension Set ID";
        GenJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, TransReceiptHeaderNo);
        if (GenJnlLine.Amount <> 0) then
            RunGenJnlPostLine(GenJnlLine);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforePostItemJnlLine', '', false, false)]
    local procedure SetMarking(TransferReceiptLine: Record "Transfer Receipt Line")
    begin
        ItemJournalCustom := TransferReceiptLine."Custom Duty Amount" + GSTAmountLoaded;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterItemValuePosting', '', false, false)]
    local procedure InitRevaluationEntryForGSTAndUnrealizedProfit(var ItemJournalLine: Record "Item Journal Line"; var ValueEntry: Record "Value Entry")
    begin
        // InitRevaluationEntryGST(ItemJournalLine);
        // InitRevaluationEntryUnrealizedProfit(ItemJournalLine, ValueEntry);
    end;

    local procedure FillDetailLedgBufferTransfer(DocNo: Code[20])
    var
        TransferLine: Record "Transfer Line";
        TransferHeader: Record "Transfer Header";
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        GSTSetup: Record "GST Setup";
        TaxTransactionValue: Record "Tax Transaction value";
        Item: Record Item;

    begin
        if not GSTSetup.Get() then
            exit;

        GSTSetup.TestField("GST Tax Type");
        GSTSetup.TestField("Cess Tax Type");

        TransferHeader.Get(DocNo);

        TransferLine.Reset();
        TransferLine.SetRange("Document No.", DocNo);
        if TransferLine.FindSet() then
            repeat
                if (TransferLine."Item No." <> '') and (TransferLine."Qty. to Receive" <> 0) then begin
                    Item.Get(TransferLine."Item No.");
                    TransferLine.TestField(Quantity);

                    TaxTransactionValue.Reset();
                    TaxTransactionValue.SetFilter("Tax Type", '%1|%2', GSTSetup."GST Tax Type", GSTSetup."Cess Tax Type");
                    TaxTransactionValue.SetRange("Tax Record ID", TransferLine.RecordId);
                    TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
                    TaxTransactionValue.SetFilter(Amount, '<>%1', 0);
                    if TaxTransactionValue.FindSet() then
                        repeat
                            FillDetailedGSTEntryBuffer(DetailedGSTEntryBuffer, TransferHeader, Item, TransferLine, TaxTransactionValue);
                        until TaxTransactionValue.Next() = 0;
                end;
            until TransferLine.Next() = 0;
    end;


    local procedure CheckValidations(TransferHeader: Record "Transfer Header")
    var
        Location: Record Location;
        TransferLine: Record "Transfer Line";
    begin
        if not location.Get(TransferHeader."Transfer-from Code") then
            exit;

        if not Location."Bonded warehouse" then
            exit;

        TransferLine.Reset();
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        TransferLine.SetFilter(Quantity, '<>0');
        TransferLine.SetRange("Derived From Line No.", 0);
        TransferLine.SetFilter("Qty. to Receive", '<>0');
        if TransferLine.FindSet() then
            repeat
                if not IsGSTGroupForGoods(TransferLine) then
                    Error(GSTGroupServiceErr);

                if (TransferLine."GST Assessable Value" <> 0) and (not IsGSTGroupForGoods(TransferLine)) then
                    Error(GSTAssessableErr);

                if (TransferLine."Custom Duty Amount" <> 0) and (not IsGSTGroupForGoods(TransferLine)) then
                    Error(GSTCustomDutyErr);

                TransferLine.TestField("GST Assessable Value");
            until TransferLine.Next() = 0;

        TransferHeader.TestField("Vendor No.");
        TransferHeader.TestField("Bill of Entry Date");
        TransferHeader.TestField("Bill of Entry No.");
    end;

    local procedure IsGSTGroupForGoods(TransferLine: Record "Transfer Line"): Boolean
    var
        GSTGroup: Record "GST Group";
    begin
        if (GSTGroup.Get(TransferLine."GST Group Code") and (GSTGroup."GST Group Type" = GSTGroup."GST Group Type"::Goods)) then
            exit(true);
    end;

    local procedure RoundTotalGSTAmountLoadedQtyFactor(
        TransactionType: Enum "Transaction Type Enum";
                             DocumentType: Enum "Document Type Enum";
                             DocumentNo: Code[20];
                             LineNo: Integer;
                             QtyFactor: Decimal;
                             CurrencyCode: Code[10]): Decimal
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        TotalGSTAmount: Decimal;
        Sign: Integer;
    begin
        DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
        DetailedGSTEntryBuffer.SetRange("Transaction Type", TransactionType);
        DetailedGSTEntryBuffer.SetRange("Document Type", DocumentType);
        DetailedGSTEntryBuffer.SetRange("Document No.", DocumentNo);
        DetailedGSTEntryBuffer.SetRange("Line No.", LineNo);
        if DetailedGSTEntryBuffer.FindSet() then
            repeat
                if DetailedGSTEntryBuffer."Amount Loaded on Item" <> 0 then
                    TotalGSTAmount += DetailedGSTEntryBuffer."Amount Loaded on Item" * QtyFactor;

                if CurrencyCode = '' then
                    TotalGSTAmount := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", TotalGSTAmount);

            until DetailedGSTEntryBuffer.Next() = 0;

        Sign := GSTBaseValidation.GETSignTransfer(DocumentType, TransactionType);
        exit(TotalGSTAmount * Sign);
    end;

    // local procedure FillGSTPostingBuffer(TransferLine: Record "Transfer Line")
    // var
    //     Location: Record Location;
    //     BondedLocation: Record Location;
    //     DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
    //     TransferHeader: Record "Transfer Header";
    //     QFactor: Decimal;
    //     GSTStateCode: Code[10];
    // begin
    //     TransferHeader.Get(TransferLine."Document No.");
    //     if not Location.Get(TransferHeader."Transfer-to Code") then
    //         exit;

    //     if not BondedLocation.Get(TransferHeader."Transfer-from Code") then
    //         exit;

    //     Location.TestField("State Code");
    //     GSTStateCode := Location."State Code";

    //     DetailedGSTEntryBuffer.Reset();
    //     DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
    //     DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
    //     DetailedGSTEntryBuffer.SetRange("Document Type", 0);
    //     DetailedGSTEntryBuffer.SetRange("Document No.", TransferLine."Document No.");
    //     DetailedGSTEntryBuffer.SetRange("Line No.", TransferLine."Line No.");
    //     DetailedGSTEntryBuffer.SetFilter("GST Base Amount", '<>%1', 0);
    //     if DetailedGSTEntryBuffer.FindSet() then
    //         repeat
    //             TempGSTPostingBufferStage.Type := TempGSTPostingBufferStage.Type::Item;
    //             TempGSTPostingBufferStage."Global Dimension 1 Code" := TransferLine."Shortcut Dimension 1 Code";
    //             TempGSTPostingBufferStage."Global Dimension 2 Code" := TransferLine."Shortcut Dimension 2 Code";
    //             TempGSTPostingBufferStage."Gen. Prod. Posting Group" := TransferLine."Gen. Prod. Posting Group";
    //             TempGSTPostingBufferStage."GST Group Code" := TransferLine."GST Group Code";
    //             if (DetailedGSTEntryBuffer."GST Assessable Value" <> 0) or (DetailedGSTEntryBuffer."Custom Duty Amount" <> 0) then
    //                 QFactor := 1
    //             else
    //                 QFactor := Abs(TransferLine."Qty. to Receive" / TransferLine.Quantity);

    //             if BondedLocation."Bonded warehouse" then
    //                 TempGSTPostingBufferStage."GST Base Amount" := -GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent
    //                                                                 (DetailedGSTEntryBuffer."GST Component Code",
    //                                                                 (QFactor * (DetailedGSTEntryBuffer."GST Assessable Value" +
    //                                                                 DetailedGSTEntryBuffer."Custom Duty Amount")))
    //             else
    //                 TempGSTPostingBufferStage."GST Base Amount" := -GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
    //                                                                                                                     (QFactor * DetailedGSTEntryBuffer."GST Base Amount"));
    //             TempGSTPostingBufferStage."GST Amount" := -GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", (QFactor * DetailedGSTEntryBuffer."GST Amount"));
    //             TempGSTPostingBufferStage."GST %" := DetailedGSTEntryBuffer."GST %";
    //             TempGSTPostingBufferStage."GST Component Code" := DetailedGSTEntryBuffer."GST Component Code";
    //             TempGSTPostingBufferStage."Custom Duty Amount" := DetailedGSTEntryBuffer."Custom Duty Amount";
    //             if (not DetailedGSTEntryBuffer."Non-Availment") and (TempGSTPostingBufferStage."GST Amount" <> 0) then
    //                 TempGSTPostingBufferStage."Account No." := GetGSTReceivableAccountNo(GSTStateCode, DetailedGSTEntryBuffer."GST Component Code")
    //             else
    //                 TempGSTPostingBufferStage."Account No." := '';

    //             UpdateGSTPostingBuffer(TransferLine);
    //         until DetailedGSTEntryBuffer.Next() = 0;
    // end;


    // local procedure ApplyFilterOnTempGSTPostingBufferFinal(
    //     var TempGSTPostingBufferFinal: Record "GST Posting Buffer";
    //     var TempGSTPostingBufferStage: Record "GST Posting Buffer")
    // begin
    //     TempGSTPostingBufferFinal.SetRange(Type, TempGSTPostingBufferStage.Type);
    //     TempGSTPostingBufferFinal.SetRange("Transaction Type", TempGSTPostingBufferStage."Transaction Type");
    //     TempGSTPostingBufferFinal.SetRange("Global Dimension 1 Code", TempGSTPostingBufferStage."Global Dimension 1 Code");
    //     TempGSTPostingBufferFinal.SetRange("Global Dimension 2 Code", TempGSTPostingBufferStage."Global Dimension 2 Code");
    //     TempGSTPostingBufferFinal.SetRange("Dimension Set ID", TempGSTPostingBufferStage."Dimension Set ID");
    //     TempGSTPostingBufferFinal.SetRange("Account No.", TempGSTPostingBufferStage."Account No.");
    //     TempGSTPostingBufferFinal.SetRange("Gen. Bus. Posting Group", TempGSTPostingBufferStage."Gen. Bus. Posting Group");
    //     TempGSTPostingBufferFinal.SetRange("Gen. Prod. Posting Group", TempGSTPostingBufferStage."Gen. Prod. Posting Group");
    //     TempGSTPostingBufferFinal.SetRange("GST Component Code", TempGSTPostingBufferStage."GST Component Code");
    //     TempGSTPostingBufferFinal.SetRange(Availment, TempGSTPostingBufferStage.Availment);
    // end;


    local procedure GetIGSTImportAccountNo(LocationCode: Code[10]): Code[20]
    var
        GSTPostingSetup: Record "GST Posting Setup";
        Location: Record Location;
    begin
        if not Location.Get(LocationCode) then
            exit;

        GSTPostingSetup.Reset();
        GSTPostingSetup.SetRange("State Code", Location."State Code");
        GSTPostingSetup.SetRange("Component ID", GSTComponentID('IGST'));
        GSTPostingSetup.FindFirst();
        exit(GSTPostingSetup."IGST Payable A/c (Import)")
    end;


    local procedure GetGSTComponent(ComponentID: Integer): Code[30]
    var
        GSTSetup: Record "GST Setup";
        TaxComponent: Record "Tax Component";
    begin
        if not GSTSetup.Get() then
            exit;

        GSTSetup.TestField("GST Tax Type");
        GSTSetup.TestField("Cess Tax Type");
        TaxComponent.SetFilter("Tax Type", '%1|%2', GSTSetup."GST Tax Type", GSTSetup."Cess Tax Type");
        TaxComponent.SetRange(Id, ComponentID);
        if TaxComponent.FindFirst() then
            exit(TaxComponent.Name);
    end;


    local procedure FillTransferBuffer(TransferLine: Record "Transfer Line")
    var
        Vendor: Record Vendor;
        GeneralPostingSetup: Record "General Posting Setup";
        LocationBonded: Record Location;
        TransferHeader: Record "Transfer Header";
        DocTransactionType: Enum "Transaction Type Enum";
        DocumentType: Enum "Document Type Enum";
    begin
        if (TransferLine."GST Group Code" = '') or (TransferLine."HSN/SAC Code" = '') then
            exit;

        if TransferLine."Qty. to Receive" = 0 then
            exit;

        Clear(TempTransferBufferStage);
        TransferHeader.Get(TransferLine."Document No.");
        LocationBonded.Get(TransferHeader."Transfer-from Code");

        if (TransferHeader."Vendor No." <> '') and (LocationBonded."Bonded warehouse") then begin
            Vendor.Get(TransferHeader."Vendor No.");
            GeneralPostingSetup.Get(Vendor."Gen. Bus. Posting Group", TransferLine."Gen. Prod. Posting Group");
            GeneralPostingSetup.TestField("Purch. Account");
            TempTransferBufferStage."Gen. Bus. Posting Group" := Vendor."Gen. Bus. Posting Group";
            TempTransferBufferStage."G/L Account" := GeneralPostingSetup."Purch. Account";
        end;

        TempTransferBufferStage."Gen. Prod. Posting Group" := TransferLine."Gen. Prod. Posting Group";
        TempTransferBufferStage."System-Created Entry" := true;
        TempTransferBufferStage."Location Code" := TransferLine."Transfer-to Code";
        TempTransferBufferStage."Item No." := TransferLine."Item No.";
        TempTransferBufferStage.Quantity := TransferLine."Qty. to Receive";
        TempTransferBufferStage."Inventory Posting Group" := TransferLine."Inventory Posting Group";
        TempTransferBufferStage."Global Dimension 1 Code" := TransferLine."Shortcut Dimension 1 Code";
        TempTransferBufferStage."Global Dimension 2 Code" := TransferLine."Shortcut Dimension 2 Code";
        TempTransferBufferStage."Dimension Set ID" := TransferLine."Dimension Set ID";
        TempTransferBufferStage."Charges Amount" := TransferLine."Charges to Transfer";
        TempTransferBufferStage."Amount Loaded on Inventory" := TransferLine."Amount Added to Inventory";
        TempTransferBufferStage.Amount := Round(TransferLine.Amount - (-TransferCost));
        if LocationBonded."Bonded warehouse" then
            TempTransferBufferStage."GST Amount" := -Round(
                RoundTotalGSTAmountQtyFactor(
                    DocTransactionType::Transfer,
                    DocumentType::Quote,
                    TransferLine."Document No.",
                    TransferLine."Line No.",
                    1,
                    '',
                    false)
            )
        else
            TempTransferBufferStage."GST Amount" := Round(
                RoundTotalGSTAmountQtyFactor(
                    DocTransactionType::Transfer,
                    DocumentType::Quote,
                    TransferLine."Document No.",
                    TransferLine."Line No.",
                    TransferLine."Qty. to Receive" / TransferLine.Quantity,
                    '',
                    false)
                );

        if TransferLine."Custom Duty Amount" <> 0 then
            TempTransferBufferStage."Custom Duty Amount" := TransferLine."Custom Duty Amount";

        if TransferLine.Quantity <> 0 then
            TempTransferBufferStage."GST Amount Loaded on Inventory" := Abs(
                RoundTotalGSTAmountLoadedQtyFactor(
                    DocTransactionType::Transfer,
                    DocumentType::Quote,
                    TransferLine."Document No.",
                    TransferLine."Line No.",
                    TransferLine."Qty. to Receive" / TransferLine.Quantity, '')
            );

        GSTAmountLoaded := TempTransferBufferStage."GST Amount Loaded on Inventory";
        UpdTransferBuffer();
    end;


    local procedure UpdTransferBuffer()
    var
        DimensionManagement: Codeunit DimensionManagement;
    begin
        DimensionManagement.UpdateGlobalDimFromDimSetID(TempTransferBufferStage."Dimension Set ID",
          TempTransferBufferStage."Global Dimension 1 Code", TempTransferBufferStage."Global Dimension 2 Code");
        ApplyFilterOnTempTransferBufferFinal(TempTransferBufferFinal, TempTransferBufferStage);
        if TempTransferBufferFinal.FindFirst() then begin
            TempTransferBufferFinal.Amount := TempTransferBufferFinal.Amount + TempTransferBufferStage.Amount;
            TempTransferBufferFinal."Amount Loaded on Inventory" := TempTransferBufferFinal."Amount Loaded on Inventory" + TempTransferBufferStage."Amount Loaded on Inventory";
            TempTransferBufferFinal."Charges Amount" := TempTransferBufferFinal."Charges Amount" + TempTransferBufferStage."Charges Amount";
            TempTransferBufferFinal.Quantity := TempTransferBufferFinal.Quantity + TempTransferBufferStage.Quantity;
            TempTransferBufferFinal."GST Amount" := TempTransferBufferFinal."GST Amount" + TempTransferBufferStage."GST Amount";
            TempTransferBufferFinal."GST Amount Loaded on Inventory" := TempTransferBufferFinal."GST Amount Loaded on Inventory" +
                TempTransferBufferStage."GST Amount Loaded on Inventory";
            TempTransferBufferFinal."Custom Duty Amount" := TempTransferBufferFinal."Custom Duty Amount" + TempTransferBufferStage."Custom Duty Amount";
            if not TempTransferBufferStage."System-Created Entry" then
                TempTransferBufferFinal."System-Created Entry" := false;

            TempTransferBufferFinal.Modify();
        end else begin
            TempTransferBufferFinal := TempTransferBufferStage;
            TempTransferBufferFinal.Insert();
        end;
    end;

    local procedure ApplyFilterOnTempTransferBufferFinal(
            var TempTransferBufferFinal: Record "Transfer Buffer";
            var TempTransferBufferStage: Record "Transfer Buffer")
    begin
        TempTransferBufferFinal.SetRange(Type, TempTransferBufferStage.Type);
        TempTransferBufferFinal.SetRange("G/L Account", TempTransferBufferStage."G/L Account");
        TempTransferBufferFinal.SetRange("Gen. Bus. Posting Group", TempTransferBufferStage."Gen. Bus. Posting Group");
        TempTransferBufferFinal.SetRange("Gen. Prod. Posting Group", TempTransferBufferStage."Gen. Prod. Posting Group");
        TempTransferBufferFinal.SetRange("Inventory Posting Group", TempTransferBufferStage."Inventory Posting Group");
        TempTransferBufferFinal.SetRange("Item No.", TempTransferBufferStage."Item No.");
    end;

    // local procedure RunGenJnlPostLine(var GenJournalLine: Record "Gen. Journal Line")
    // begin
    //     GenJnlPostLine.RunWithCheck(GenJournalLine);
    // end;

    local procedure GSTPostingBufferforTransferDocument(CustomDutyBase: Boolean; TransferHeader: Record "Transfer Header")
    begin
        if FirstExecution then begin
            TempGSTPostingBufferFinal.Reset();
            if TempGSTPostingBufferFinal.FindLast() then
                repeat
                    if (TempGSTPostingBufferFinal."Custom Duty Amount" <> 0) and (not CustomDutyBase) then begin
                        CustomDutyBase := true;
                        TempGSTPostingBufferFinal."Custom Duty Amount" := CustomDutyAmount;
                        FillGenJnlLineForCustomDuty(TransferHeader);
                    end;

                    PostTransLineToGenJnlLine(TransferHeader);
                until TempGSTPostingBufferFinal.Next(-1) = 0;

            FirstExecution := false;
        end;
    end;

    local procedure GetCustomDutyAmount(DocumentNo: Code[20])
    var
        TransferLine: Record "Transfer Line";
    begin
        TransferLine.SetRange("Document No.", DocumentNo);
        TransferLine.SetFilter("Qty. to Receive", '<>%1', 0);
        TransferLine.SetFilter("Custom Duty Amount", '<>%1', 0);
        TransferLine.SetRange("Derived From Line No.", 0);
        if TransferLine.FindSet() then
            repeat
                CustomDutyAmount += TransferLine."Custom Duty Amount";
            until TransferLine.Next() = 0;
    end;

    local procedure PostTransLineToGenJnlLine(TransferHeader: Record "Transfer Header")
    var
        SourceCodeSetup: Record "Source Code Setup";
        DocTransferType: Enum "Doc Transfer Type";
    begin
        GenJnlLine.Init();
        GenJnlLine."Posting Date" := TransferHeader."Posting Date";
        GenJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, TransReceiptHeaderNo);
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        GenJnlLine."Document No." := TransReceiptHeaderNo;
        GenJnlLine."External Document No." := TransferHeader."No.";
        if TempGSTPostingBufferfinal."GST Amount" <> 0 then begin
            GenJnlLine.Validate(Amount, Round(TempGSTPostingBufferfinal."GST Amount"));
            GenJnlLine."Account No." := TempGSTPostingBufferfinal."Account No.";
        end;

        GenJnlLine."VAT Posting" := GenJnlLine."VAT Posting"::"Manual VAT Entry";
        GenJnlLine."GST Group Code" := TempGSTPostingBufferfinal."GST Group Code";
        GenJnlLine."GST Component Code" := TempGSTPostingBufferfinal."GST Component Code";
        GenJnlLine."System-Created Entry" := TempTransferBufferFinal."System-Created Entry";
        GenJnlLine."Gen. Bus. Posting Group" := TempGSTPostingBufferfinal."Gen. Bus. Posting Group";
        GenJnlLine."Gen. Prod. Posting Group" := TempGSTPostingBufferfinal."Gen. Prod. Posting Group";
        GenJnlLine."Shortcut Dimension 1 Code" := TempGSTPostingBufferfinal."Global Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := TempGSTPostingBufferfinal."Global Dimension 2 Code";
        GenJnlLine."Dimension Set ID" := TempGSTPostingBufferfinal."Dimension Set ID";
        GenJnlLine."Location Code" := TransferHeader."Transfer-to Code";
        SourceCodeSetup.Get();
        GenJnlLine."Source Code" := SourceCodeSetup.Transfer;
        GenJnlLine."Account Type" := GenJnlLine."Account Type"::"G/L Account";
        if TempGSTPostingBufferFinal."Account No." <> '' then
            RunGenJnlPostLine(GenJnlLine);

        InsertGSTLedgerEntryTransfer(
            TempGSTPostingBufferFinal,
            TransferHeader,
            GenJnlPostLine.GetNextTransactionNo(),
            GenJnlLine."Document No.",
            SourceCodeSetup.Transfer,
            DocTransferType::"Transfer Receipt");
    end;

    local procedure GSTPurchAccPosting(TransferHeader: Record "Transfer Header"; TempTransferBufferfinal: Record "Transfer Buffer")
    var
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();

        GenJnlLine.Init();
        GenJnlLine."Posting Date" := TransferHeader."Posting Date";
        GenJnlLine."Document Date" := TransferHeader."Posting Date";
        GenJnlLine."Document No." := TransReceiptHeaderNo;
        GenJnlLine."Document Type" := GenJnlLine."Document Type"::Invoice;
        GenJnlLine."Account No." := TempTransferBufferFinal."G/L Account";
        GenJnlLine."System-Created Entry" := TempTransferBufferFinal."System-Created Entry";
        GenJnlLine.Amount := TempTransferBufferFinal."Custom Duty Amount";
        GenJnlLine."Source Code" := SourceCodeSetup.Transfer;
        GenJnlLine."Gen. Bus. Posting Group" := TempTransferBufferFinal."Gen. Bus. Posting Group";
        GenJnlLine."Gen. Prod. Posting Group" := TempTransferBufferFinal."Gen. Prod. Posting Group";
        GenJnlLine."Shortcut Dimension 1 Code" := TempTransferBufferFinal."Global Dimension 1 Code";
        GenJnlLine."Shortcut Dimension 2 Code" := TempTransferBufferFinal."Global Dimension 2 Code";
        GenJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, TransReceiptHeaderNo);
        if GenJnlLine.Amount <> 0 then
            RunGenJnlPostLine(GenJnlLine);
    end;

    local procedure FillGenJnlLineForCustomDuty(TransferHeader: Record "Transfer Header")
    var
        SourceCodeSetup: Record "Source Code Setup";
        GenJournalLine: Record "Gen. Journal Line";
    begin
        SourceCodeSetup.Get();

        GenJournalLine.Init();
        GenJournalLine."Posting Date" := TransferHeader."Posting Date";
        GenJournalLine.Description := StrSubstNo(TransferReceiptNoLbl, TransReceiptHeaderNo);
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Invoice;
        GenJournalLine."Document No." := TransReceiptHeaderNo;
        GenJournalLine."External Document No." := TransferHeader."No.";
        GenJournalLine."System-Created Entry" := true;
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::"G/L Account";
        GenJournalLine."Account No." := GetIGSTImportAccountNo(TempTransferBufferFinal."Location Code");
        GenJournalLine."Bal. Account No." := '';
        GenJournalLine.Validate(Amount, -Round(TempGSTPostingBufferFinal."Custom Duty Amount"));
        GenJournalLine."Gen. Bus. Posting Group" := TempGSTPostingBufferFinal."Gen. Bus. Posting Group";
        GenJournalLine."Gen. Prod. Posting Group" := TempGSTPostingBufferFinal."Gen. Prod. Posting Group";
        GenJournalLine."Shortcut Dimension 1 Code" := TempGSTPostingBufferFinal."Global Dimension 1 Code";
        GenJournalLine."Shortcut Dimension 2 Code" := TempGSTPostingBufferFinal."Global Dimension 2 Code";
        GenJournalLine."Dimension Set ID" := TempGSTPostingBufferFinal."Dimension Set ID";
        GenJournalLine."GST Component Code" := TempGSTPostingBufferFinal."GST Component Code";
        GenJournalLine."Source Type" := GenJournalLine."Source Type"::Vendor;
        GenJournalLine."Source No." := TransferHeader."Vendor No.";
        GenJournalLine."Location Code" := TransferHeader."Transfer-from Code";
        GenJournalLine."Source Code" := SourceCodeSetup.Transfer;
        if (GenJournalLine.Amount <> 0) then
            RunGenJnlPostLine(GenJournalLine);
    end;

#if not CLEAN22
    [Obsolete('Replaced by InitRevaluationEntryUnrealizedProfit', '22.0')]
    local procedure PostRevaluationEntryunrealizedProfit(
            var TransferLine3: Record "Transfer Line";
            TransferReceiptHeader2: Record "Transfer Receipt Header";
            TransferReceiptLine2: Record "Transfer Receipt Line")
    var
        ValueEntry: Record "Value Entry";
        SourceCodeSetup: Record "Source Code Setup";
        ItemRegister: Record "Item Register";
        ItemLedgerEntry: Record "Item Ledger Entry";
        TransferHeader: Record "Transfer Header";
        Location: Record Location;
        ItemJournalLine: Record "Item Journal Line";
        Ctr: Integer;
        TransferPriceDiff: Decimal;
        EntryNo: Integer;
        TotalTransferPriceDiff: Decimal;
        Amnt: Decimal;
        AmntUnitCost: Decimal;
    begin
        if TransferLine3."Qty. to Receive" = 0 then
            exit;

        Location.Get(TransferReceiptHeader2."Transfer-from Code");
        if Location."Bonded warehouse" then
            exit;

        TransferHeader.Get(TransferLine3."Document No.");
        if not TransferHeader."Load Unreal Prof Amt on Invt." then
            exit;

        Amnt := -TransferCost;
        RoundDiffAmt := TransferLine3.Amount - Amnt;
        TotalTransferPriceDiff := 0;
        SourceCodeSetup.Get();
        ItemRegister.SetFilter("Source Code", '<>%1', SourceCodeSetup."Revaluation Journal");
        ItemRegister.FindLast();

        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetCurrentKey("Location Code", "Posting Date", "Document No.", "Item No.");
        ItemLedgerEntry.SetRange("Entry No.", ItemRegister."From Entry No.", ItemRegister."To Entry No.");
        ItemLedgerEntry.SetRange("Location Code", TransferReceiptHeader2."Transfer-to Code");
        ItemLedgerEntry.SetRange("Posting Date", TransferReceiptHeader2."Posting Date");
        ItemLedgerEntry.SetRange("Document No.", TransferReceiptHeader2."No.");
        ItemLedgerEntry.SetRange("Document Line No.", TransferLine3."Line No.");
        ItemLedgerEntry.SetRange("Item No.", TransferLine3."Item No.");
        if ItemLedgerEntry.FindLast() then
            EntryNo := ItemLedgerEntry."Entry No.";

        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetCurrentKey("Location Code", "Posting Date", "Document No.", "Item No.");
        ItemLedgerEntry.SetRange("Entry No.", ItemRegister."From Entry No.", ItemRegister."To Entry No.");
        ItemLedgerEntry.SetRange("Location Code", TransferReceiptHeader2."Transfer-to Code");
        ItemLedgerEntry.SetRange("Posting Date", TransferReceiptHeader2."Posting Date");
        ItemLedgerEntry.SetRange("Document No.", TransferReceiptHeader2."No.");
        ItemLedgerEntry.SetRange("Document Line No.", TransferLine3."Line No.");
        ItemLedgerEntry.SetRange("Item No.", TransferLine3."Item No.");
        if ItemLedgerEntry.Findset() then
            repeat

                ValueEntry.Reset();
                ValueEntry.SetRange("Item Ledger Entry No.", ItemLedgerEntry."Entry No.");
                ValueEntry.FindFirst();
                AmntUnitCost := ValueEntry."Cost Amount (Actual)" / ValueEntry."Item Ledger Entry Quantity";
                TransferPriceDiff := Round((TransferLine3."Transfer Price" / ItemLedgerEntry."Qty. per Unit of Measure") - AmntUnitCost);
                if TransferPriceDiff <> 0 then begin
                    TotalTransferPriceDiff += TransferPriceDiff * ItemLedgerEntry.Quantity;
                    if (EntryNo = ItemLedgerEntry."Entry No.") and (TotalTransferPriceDiff <> RoundDiffAmt) and (ItemLedgerEntry."Lot No." = '') then
                        TransferPriceDiff := TransferPriceDiff - (TotalTransferPriceDiff - RoundDiffAmt);

                    ItemJournalLine.Init();
                    ItemJournalLine.Validate("Posting Date", TransferReceiptHeader2."Posting Date");
                    ItemJournalLine."Document Date" := TransferReceiptHeader2."Posting Date";
                    ItemJournalLine.Validate("Document No.", TransferReceiptHeader2."No.");
                    ItemJournalLine."External Document No." := TransferReceiptHeader2."External Document No.";
                    ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Transfer);
                    ItemJournalLine."Value Entry Type" := ItemJournalLine."Value Entry Type"::Revaluation;
                    ItemJournalLine.Validate("Item No.", TransferReceiptLine2."Item No.");
                    ItemJournalLine.Description := TransferReceiptLine2.Description;
                    ItemJournalLine."Inventory Posting Group" := TransferReceiptLine2."Inventory Posting Group";
                    ItemJournalLine."Gen. Prod. Posting Group" := TransferLine3."Gen. Prod. Posting Group";
                    ItemJournalLine."Source Code" := SourceCodeSetup."Revaluation Journal";
                    ItemJournalLine.Validate("Applies-to Entry", ItemLedgerEntry."Entry No.");
                    ItemJournalLine.Validate("Unit Cost (Revalued)", (ItemJournalLine."Unit Cost (Revalued)" + TransferPriceDiff));
                    ItemJournalLine.Description := StrSubstNo(TransferReceiptNoLbl, TransferReceiptHeader2."No.");
                    ItemJournalLine."New Location Code" := TransferReceiptHeader2."Transfer-to Code";

                    Ctr := TempItemJnlLine."Line No." + 1;

                    TempItemJnlLine.Init();
                    TempItemJnlLine.TransferFields(ItemJournalLine);
                    TempItemJnlLine."Line No." := Ctr;
                    if ItemLedgerEntry."Lot No." <> '' then
                        ReserveTransLine.TransferTransferToItemJnlLine(TransferLine3, TempItemJnlLine, TransferLine3."Qty. to Receive (Base)", "Transfer Direction"::Inbound);

                    ItemJnlPostLine.Run(TempItemJnlLine);
                end;
            until ItemLedgerEntry.Next() = 0;
    end;
#endif

    local procedure GetTransferReceiptPostingNoSeries(var TransferHeader: Record "Transfer Header"): Code[20]
    var
        PostingNoSeries: Record "Posting No. Series";
        NoSeriesCode: Code[20];
    begin
        PostingNoSeries.SetRange("Table Id", Database::"Transfer Header");
        NoSeriesCode := LoopPostingNoSeries(
            PostingNoSeries,
            TransferHeader,
            PostingNoSeries."Document Type"::"Transfer Receipt Header");
        exit(NoSeriesCode);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnRunWithCheckOnAfterRetrieveItemTracking', '', false, false)]
    local procedure OnRunWithCheckOnAfterRetrieveItemTracking(var ItemJournalLine: Record "Item Journal Line"; var TempTrackingSpecification: Record "Tracking Specification"; var TrackingSpecExists: Boolean)
    var
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();
        if (ItemJournalLine."Source Code" = SourceCodeSetup."Revaluation Journal") and (ItemJournalLine."Applies-to Entry" <> 0) then
            TrackingSpecExists := false;
    end;

    local procedure InitRevaluationEntryGST(var ItemJournalLine: Record "Item Journal Line")
    var
        SourceCodeSetup: Record "Source Code Setup";
        TransferReceiptLine: Record "Transfer Receipt Line";
    begin
        SourceCodeSetup.Get();

        if ItemJournalCustom = 0 then
            exit;

        if (ItemJournalLine."Source Code" <> SourceCodeSetup.Transfer) then
            exit;

        if not TransferReceiptLine.Get(ItemJournalLine."Document No.", ItemJournalLine."Document Line No.") then
            exit;



        InitRevaluationEntry(ItemJournalLine, (ItemJournalCustom / TransferReceiptLine."Quantity"));
    end;

    local procedure InitRevaluationEntryUnrealizedProfit(var ItemJournalLine: Record "Item Journal Line"; var ValueEntry: Record "Value Entry")
    var
        SourceCodeSetup: Record "Source Code Setup";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        TransferReceiptLine: Record "Transfer Receipt Line";
        Location: Record Location;
        TransferPriceDiff: Decimal;
        TotalTransferPriceDiff: Decimal;
        AmntUnitCost: Decimal;
    begin
        if not TransferReceiptLine.Get(ItemJournalLine."Document No.", ItemJournalLine."Document Line No.") then
            exit;

        SourceCodeSetup.Get();
        if (ItemJournalLine."Source Code" <> SourceCodeSetup.Transfer) then
            exit;

        TransferHeader.Get(ItemJournalLine."Order No.");
        if not TransferHeader."Load Unreal Prof Amt on Invt." then
            exit;

        Location.Get(TransferHeader."Transfer-from Code");
        if Location."Bonded warehouse" then
            exit;

        TransferLine.Get(ItemJournalLine."Order No.", ItemJournalLine."Order Line No.");

        RoundDiffAmt := TransferLine.Amount - (-TransferCost);
        TotalTransferPriceDiff := 0;

        AmntUnitCost := ValueEntry."Cost Amount (Actual)" / ValueEntry."Item Ledger Entry Quantity";
        TransferPriceDiff := Round((TransferLine."Transfer Price" / ItemJournalLine."Qty. per Unit of Measure") - AmntUnitCost);
        if TransferPriceDiff <> 0 then begin
            TotalTransferPriceDiff += TransferPriceDiff * ItemJournalLine.Quantity;
            if (TotalTransferPriceDiff <> RoundDiffAmt) and (ItemJournalLine."Lot No." = '') then
                TransferPriceDiff := TransferPriceDiff - (TotalTransferPriceDiff - RoundDiffAmt);

            InitRevaluationEntry(ItemJournalLine, TransferPriceDiff);
        end;
    end;

    local procedure InitRevaluationEntry(var ItemJournalLine: Record "Item Journal Line"; UnitCostRevalued: Decimal)
    var
        SourceCodeSetup: Record "Source Code Setup";
    begin
        SourceCodeSetup.Get();

        LineNo := LineNo + 1;

        TempItemJnlLine.Init();
        TempItemJnlLine.Validate("Posting Date", ItemJournalLine."Posting Date");
        TempItemJnlLine.Validate("Document No.", ItemJournalLine."Document No.");
        TempItemJnlLine."External Document No." := ItemJournalLine."External Document No.";
        TempItemJnlLine.Validate("Entry Type", TempItemJnlLine."Entry Type"::Transfer);
        TempItemJnlLine."Value Entry Type" := TempItemJnlLine."Value Entry Type"::Revaluation;
        TempItemJnlLine.Validate("Item No.", ItemJournalLine."Item No.");
        TempItemJnlLine."Source Code" := SourceCodeSetup."Revaluation Journal";
        TempItemJnlLine.Validate("Applies-to Entry", ItemLedgerEntryNo);
        TempItemJnlLine.Validate("Unit Cost (Revalued)", (TempItemJnlLine."Unit Cost (Revalued)" + UnitCostRevalued));
        TempItemJnlLine.Description := StrSubstNo(TransferReceiptNoLbl, ItemJournalLine."Document No.");
        TempItemJnlLine."Line No." := LineNo;
        TempItemJnlLine.Insert();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", 'OnAfterPostItemJnlLine', '', false, false)]
    local procedure OnAfterPostItemJnlLine(sender: Codeunit "Item Jnl.-Post Line"; var ItemJournalLine: Record "Item Journal Line")
    var
        TransferReceiptLine: Record "Transfer Receipt Line";
    begin
        if ItemJournalLine."Entry Type" <> ItemJournalLine."Entry Type"::Transfer then
            exit;

        if not TransferReceiptLine.Get(ItemJournalLine."Document No.", ItemJournalLine."Document Line No.") then
            exit;

        if TempItemJnlLine.IsEmpty then
            exit;

        TotalQuantity := TotalQuantity + ItemJournalLine.Quantity;

        if TotalQuantity <> TransferReceiptLine.Quantity then
            exit;

        if TempItemJnlLine.FindSet() then
            repeat
                sender.RunWithCheck(TempItemJnlLine);
            until TempItemJnlLine.Next() = 0;

        TotalQuantity := 0;
        TempItemJnlLine.DeleteAll();
    end;

    procedure GetGSTReceivableAccountNo(LocationCode: Code[10]; GSTComponentCode: Code[30]): Code[20]
    var
        GSTPostingSetup: Record "GST Posting Setup";
    begin
        GSTPostingSetup.Reset();
        GSTPostingSetup.SetRange("State Code", LocationCode);
        GSTPostingSetup.SetRange("Component ID", GSTComponentID(GSTComponentCode));
        GSTPostingSetup.FindFirst();
        exit(GSTPostingSetup."Receivable Account")
    end;

    procedure GSTComponentID(ComponentCode: Code[30]): Integer
    var
        GSTSetup: Record "GST Setup";
        TaxComponent: Record "Tax Component";
    begin
        if not GSTSetup.Get() then
            exit;

        GSTSetup.TestField("GST Tax Type");
        GSTSetup.TestField("Cess Tax Type");
        TaxComponent.SetFilter("Tax Type", '%1|%2', GSTSetup."GST Tax Type", GSTSetup."Cess Tax Type");
        TaxComponent.SetRange(Name, ComponentCode);
        if TaxComponent.FindFirst() then
            exit(TaxComponent.Id)
    end;

    procedure LoopPostingNoSeries(var PostingNoSeries: Record "Posting No. Series"; Record: Variant; PostingDocumentType: Enum "Posting Document Type"): Code[20]
    var
        Filters: Text;
    begin
        PostingNoSeries.SetRange("Document Type", PostingDocumentType);
        if PostingNoSeries.FindSet() then
            repeat
                Filters := GetRecordView(PostingNoSeries);
                if RecordViewFound(Record, Filters) then begin
                    PostingNoSeries.TestField("Posting No. Series");
                    exit(PostingNoSeries."Posting No. Series");
                end;
            until PostingNoSeries.Next() = 0;
    end;

    procedure InsertGSTLedgerEntryTransfer(
        GSTPostingBuffer: Record "GST Posting Buffer";
        TransferHeader: Record "Transfer Header";
        NextTransactionNo: Integer;
        DocumentNo: Code[20];
        SourceCode: Code[10];
        DocTransferType: enum "Doc Transfer Type")
    var
        GSTLedgerEntry: Record "GST Ledger Entry";
        Location: Record Location;

    begin

        Location.Get(TransferHeader."Transfer-from Code");

        GSTLedgerEntry.Init();
        GSTLedgerEntry."Entry No." := 0;
        GSTLedgerEntry."Gen. Bus. Posting Group" := GSTPostingBuffer."Gen. Bus. Posting Group";
        GSTLedgerEntry."Gen. Prod. Posting Group" := GSTPostingBuffer."Gen. Prod. Posting Group";
        GSTLedgerEntry."Posting Date" := TransferHeader."Posting Date";
        GSTLedgerEntry."Document No." := DocumentNo;
        GSTLedgerEntry."Document Type" := GSTLedgerEntry."Document Type"::Invoice;
        GSTLedgerEntry."GST Base Amount" := GSTPostingBuffer."GST Base Amount";
        GSTLedgerEntry."GST Amount" := GSTPostingBuffer."GST Amount";
        GSTLedgerEntry."Source Type" := GSTLedgerEntry."Source Type"::Transfer;
        if DocTransferType = DocTransferType::"Transfer Shipment" then begin
            GSTLedgerEntry."Transaction Type" := GSTLedgerEntry."Transaction Type"::Sales;
            GSTLedgerEntry."External Document No." := TransferHeader."No.";
        end else begin
            GSTLedgerEntry."Transaction Type" := GSTLedgerEntry."Transaction Type"::Purchase;
            GSTLedgerEntry."External Document No." := TransferHeader."Last Shipment No.";
            if Location."Bonded warehouse" then begin
                GSTLedgerEntry."Source Type" := GSTLedgerEntry."Source Type"::Vendor;
                GSTLedgerEntry."Source No." := TransferHeader."Vendor No.";
                GSTLedgerEntry."Reverse Charge" := true;
            end;
        end;

        GSTLedgerEntry."GST Base Amount" := GSTPostingBuffer."GST Base Amount";
        GSTLedgerEntry."User ID" := CopyStr(UserId, 1, MaxStrLen(GSTLedgerEntry."User ID"));
        GSTLedgerEntry."Source Type" := GSTLedgerEntry."Source Type"::Transfer;
        GSTLedgerEntry."Source Code" := SourceCode;
        GSTLedgerEntry."Transaction No." := NextTransactionNo;
        GSTLedgerEntry."GST Component Code" := GSTPostingBuffer."GST Component Code";

        GSTLedgerEntry.Insert(true);
    end;

    procedure InsertDetailedGSTLedgEntryTransfer(
        var TransferLine: Record "Transfer Line";
        TransferHeader: Record "Transfer Header";
        DocumentNo: Code[20];
        TransactionNo: Integer;
        DocTransferType: Enum "Doc Transfer Type")
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        Location: Record Location;
        Location2: Record Location;
        TaxTransactionValue: Record "Tax Transaction Value";
        ShipRcvQuantity: Decimal;
        IsHandled: Boolean;
    begin


        if (TransferLine."GST Group Code" = '') or (TransferLine."HSN/SAC Code" = '') then
            exit;

        TaxTransactionValue.SetRange("Tax Record ID", TransferLine.RecordId);
        if TaxTransactionValue.IsEmpty then
            exit;

        Location.Get(TransferHeader."Transfer-from Code");
        if not Location."Bonded warehouse" then begin
            Location.TestField("State Code");
            if (Location."GST Registration No." = '') and (Location."Location ARN No." = '') then
                Error(LocGSTRegNoARNNoErr);
        end;

        Location2.Get(TransferHeader."Transfer-to Code");
        if (Location2."GST Registration No." = '') and (Location2."Location ARN No." = '') then
            Error(LocGSTRegNoARNNoErr);

        DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
        DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
        DetailedGSTEntryBuffer.SetRange("Document Type", 0);
        DetailedGSTEntryBuffer.SetRange("Document No.", TransferLine."Document No.");
        DetailedGSTEntryBuffer.SetRange("Line No.", TransferLine."Line No.");
        DetailedGSTEntryBuffer.SetFilter("GST Amount", '%1', 0);
        if DetailedGSTEntryBuffer.FindSet() then
            repeat
                DetailedGSTLedgerEntry.Init();
                DetailedGSTLedgerEntry."Entry No." := 0;
                DetailedGSTLedgerEntry."Entry Type" := DetailedGSTLedgerEntry."Entry Type"::"Initial Entry";
                if DocTransferType = DocTransferType::"Transfer Shipment" then
                    DetailedGSTLedgerEntry."Transaction Type" := DetailedGSTLedgerEntry."Transaction Type"::Sales
                else
                    DetailedGSTLedgerEntry."Transaction Type" := DetailedGSTLedgerEntry."Transaction Type"::Purchase;

                DetailedGSTLedgerEntry."Document Type" := DetailedGSTLedgerEntry."Document Type"::Invoice;
                DetailedGSTLedgerEntry."Document No." := DocumentNo;
                DetailedGSTLedgerEntry."Posting Date" := TransferHeader."Posting Date";
                DetailedGSTLedgerEntry.Type := DetailedGSTLedgerEntry.Type::Item;
                DetailedGSTLedgerEntry."Product Type" := DetailedGSTLedgerEntry."Product Type"::Item;
                DetailedGSTLedgerEntry."No." := TransferLine."Item No.";
                DetailedGSTLedgerEntry."GST Jurisdiction Type" := GETGSTJurisdictionType(TransferHeader);
                DetailedGSTLedgerEntry."GST Group Type" := "GST Group Type"::Goods;
                DetailedGSTLedgerEntry."GST Without Payment of Duty" := false;
                DetailedGSTLedgerEntry."GST Component Code" := DetailedGSTEntryBuffer."GST Component Code";
                DetailedGSTLedgerEntry."GST Exempted Goods" := TransferLine.Exempted;
                if DocTransferType = DocTransferType::"Transfer Shipment" then begin
                    DetailedGSTLedgerEntry."G/L Account No." := GetGSTPayableAccountNo(Location."State Code", DetailedGSTEntryBuffer."GST Component Code");
                    ShipRcvQuantity := TransferLine."Qty. to Ship (Base)";
                    FillDetailedGSTLedgerEntryShipment(DetailedGSTLedgerEntry, Location, Location2, TransferHeader);
                end else begin
                    DetailedGSTLedgerEntry."G/L Account No." := GetGSTReceivableAccountNo(Location2."State Code", DetailedGSTEntryBuffer."GST Component Code");
                    ShipRcvQuantity := TransferLine."Qty. to Receive (Base)";
                    FillDetailedGSTLedgerEntryReceipt(DetailedGSTLedgerEntry, Location, Location2, TransferHeader, TransferLine);
                end;

                UpdateDetailedGSTLedgerEntryTransfer(
                  DetailedGSTLedgerEntry,
                  TransferLine."Document No.",
                  TransferLine."Line No.",
                  TransactionNo,
                  TransferLine."Quantity (Base)",
                  ShipRcvQuantity,
                  DocTransferType);
                DetailedGSTLedgerEntry.TestField("HSN/SAC Code");
                DetailedGSTLedgerEntry."Skip Tax Engine Trigger" := true;
                DetailedGSTLedgerEntry.Insert(true);

                InsertDetailedGSTEntryInfoTransfer(DetailedGSTLedgerEntry, DetailedGSTEntryBuffer, TransferHeader, DocTransferType);
            until DetailedGSTEntryBuffer.Next() = 0;
    end;

    local procedure InsertDetailedGSTEntryInfoTransfer(
            DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
            DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
            TransferHeader: Record "Transfer Header";
            DocTransferType: Enum "Doc Transfer Type")
    var
        DetailedGSTLedgerEntryInfo: Record "Detailed GST Ledger Entry Info";
        Location: Record Location;
        Location2: Record Location;
        IsHandled: Boolean;
    begin

        Location.Get(TransferHeader."Transfer-from Code");
        Location2.Get(TransferHeader."Transfer-to Code");

        DetailedGSTLedgerEntryInfo.Init();
        DetailedGSTLedgerEntryInfo."Entry No." := DetailedGSTLedgerEntry."Entry No.";
        DetailedGSTLedgerEntryInfo."Original Doc. No." := TransferHeader."No.";
        DetailedGSTLedgerEntryInfo.Positive := DetailedGSTLedgerEntry."GST Amount" > 0;
        DetailedGSTLedgerEntryInfo."User ID" := CopyStr(UserId, 1, MaxStrLen(DetailedGSTLedgerEntryInfo."User ID"));
        DetailedGSTLedgerEntryInfo.Cess := DetailedGSTEntryBuffer.Cess;
        DetailedGSTLedgerEntryInfo."Component Calc. Type" := DetailedGSTEntryBuffer."Component Calc. Type";
        DetailedGSTLedgerEntryInfo."Cess Amount Per Unit Factor" := DetailedGSTEntryBuffer."Cess Amt Per Unit Factor (LCY)";
        DetailedGSTLedgerEntryInfo."Cess UOM" := DetailedGSTEntryBuffer."Cess UOM";
        DetailedGSTLedgerEntryInfo."Cess Factor Quantity" := DetailedGSTEntryBuffer."Cess Factor Quantity";
        DetailedGSTLedgerEntryInfo.UOM := DetailedGSTEntryBuffer.UOM;
        DetailedGSTLedgerEntryInfo."From Location Code" := TransferHeader."Transfer-from Code";
        DetailedGSTLedgerEntryInfo."To Location Code" := TransferHeader."Transfer-to Code";
        if DocTransferType = DocTransferType::"Transfer Shipment" then begin
            DetailedGSTLedgerEntryInfo."Location ARN No." := Location."Location ARN No.";
            DetailedGSTLedgerEntryInfo."Location State Code" := Location."State Code";
            DetailedGSTLedgerEntryInfo."Buyer/Seller State Code" := Location2."State Code";
            DetailedGSTLedgerEntryInfo."Shipping Address State Code" := '';
            DetailedGSTLedgerEntryInfo."Original Doc. Type" := DetailedGSTLedgerEntryInfo."Original Doc. Type"::"Transfer Shipment";
            DetailedGSTLedgerEntryInfo."Sales Invoice Type" := "Sales Invoice Type"::"Bill of Supply";
        end else begin
            DetailedGSTLedgerEntryInfo."Location ARN No." := Location2."Location ARN No.";
            DetailedGSTLedgerEntryInfo."Location State Code" := Location2."State Code";
            DetailedGSTLedgerEntryInfo."Buyer/Seller State Code" := Location."State Code";
            DetailedGSTLedgerEntryInfo."Shipping Address State Code" := '';
            DetailedGSTLedgerEntryInfo."Original Doc. Type" := DetailedGSTLedgerEntryInfo."Original Doc. Type"::"Transfer Receipt";
            if Location."Bonded warehouse" then begin
                DetailedGSTLedgerEntryInfo."Buyer/Seller State Code" := '';
                DetailedGSTLedgerEntryInfo."Bill of Entry No." := TransferHeader."Bill of Entry No.";
                DetailedGSTLedgerEntryInfo."Bill of Entry Date" := TransferHeader."Bill of Entry Date";
            end;
        end;
        DetailedGSTLedgerEntryInfo.Insert(true);
    end;

    local procedure FillDetailLedgBufferTransferSales(DocNo: Code[20])
    var
        TransferLine: Record "Transfer Line";
        TransferHeader: Record "Transfer Header";
        GeneralLedgerSetup: Record "General Ledger Setup";
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        GSTGroup: Record "GST Group";
        GSTSetup: Record "GST Setup";
        TaxTransactionValue: Record "Tax Transaction Value";
        Item: Record Item;
        Sign: Integer;
        DocumentType: Enum "Document Type Enum";
        TransactionType: Enum "Transaction Type Enum";
    begin
        if not GSTSetup.Get() then
            exit;

        GSTSetup.TestField("GST Tax Type");
        GSTSetup.TestField("Cess Tax Type");

        TransferHeader.Get(DocNo);
        GeneralLedgerSetup.Get();
        Sign := GSTBaseValidation.GetSignTransfer(DocumentType::Quote, TransactionType::"Transfer");

        TransferLine.Reset();
        TransferLine.SetRange("Document No.", DocNo);
        if TransferLine.FindSet() then
            repeat
                if (TransferLine."Item No." <> '') and (TransferLine."Qty. to Ship" <> 0) then begin
                    TransferLine.TestField(Quantity);
                    Item.Get(TransferLine."Item No.");
                    TaxTransactionValue.Reset();
                    TaxTransactionValue.SetFilter("Tax Type", '%1|%2', GSTSetup."GST Tax Type", GSTSetup."Cess Tax Type");
                    TaxTransactionValue.SetRange("Tax Record ID", TransferLine.RecordId);
                    TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
                    TaxTransactionValue.SetFilter(Amount, '%1', 0);
                    if TaxTransactionValue.FindSet() then
                        repeat
                            DetailedGSTEntryBuffer.Init();
                            DetailedGSTEntryBuffer."Entry No." := 0;
                            DetailedGSTEntryBuffer."Document Type" := DetailedGSTEntryBuffer."Document Type"::Quote;
                            DetailedGSTEntryBuffer."Document No." := TransferHeader."No.";
                            DetailedGSTEntryBuffer."Posting Date" := TransferHeader."Posting Date";
                            DetailedGSTEntryBuffer."Transaction Type" := DetailedGSTEntryBuffer."Transaction Type"::transfer;
                            DetailedGSTEntryBuffer.Type := DetailedGSTEntryBuffer.Type::Item;
                            DetailedGSTEntryBuffer.UOM := Item."Base Unit of Measure";
                            DetailedGSTEntryBuffer."No." := TransferLine."Item No.";
                            DetailedGSTEntryBuffer."Source No." := '';
                            DetailedGSTEntryBuffer.Quantity := TransferLine.Quantity * Sign;
                            DetailedGSTEntryBuffer."HSN/SAC Code" := TransferLine."HSN/SAC Code";
                            DetailedGSTEntryBuffer.Exempted := TransferLine.Exempted;
                            DetailedGSTEntryBuffer."Location Code" := TransferHeader."Transfer-from Code";
                            DetailedGSTEntryBuffer."Line No." := TransferLine."Line No.";
                            DetailedGSTEntryBuffer."Source Type" := "Source Type"::" ";
                            DetailedGSTEntryBuffer."GST Input/Output Credit Amount" := Sign * TaxTransactionValue.Amount;
                            DetailedGSTEntryBuffer."GST Base Amount" := Sign * TransferLine.Amount;
                            DetailedGSTEntryBuffer."GST %" := TaxTransactionValue.Percent;
                            DetailedGSTEntryBuffer."Currency Factor" := 1;
                            DetailedGSTEntryBuffer."GST Amount" := Sign * TaxTransactionValue.Amount;
                            DetailedGSTEntryBuffer."Custom Duty Amount" := TransferLine."Custom Duty Amount";
                            DetailedGSTEntryBuffer."GST Assessable Value" := TransferLine."GST Assessable Value";
                            if TransferLine."GST Credit" = TransferLine."GST Credit"::"Non-Availment" then begin
                                DetailedGSTEntryBuffer."Amount Loaded on Item" := Sign * TaxTransactionValue.Amount;
                                DetailedGSTEntryBuffer."Non-Availment" := true;
                            end else
                                DetailedGSTEntryBuffer."GST Input/Output Credit Amount" := Sign * TaxTransactionValue.Amount;
                            if TaxTransactionValue."Tax Type" = GSTSetup."Cess Tax Type" then
                                DetailedGSTEntryBuffer."GST Component Code" := 'CESS'
                            else
                                DetailedGSTEntryBuffer."GST Component Code" := GetGSTComponent(TaxTransactionValue."Value ID");
                            DetailedGSTEntryBuffer."GST Group Code" := TransferLine."GST Group Code";
                            if GSTGroup.Get(TransferLine."GST Group Code") and (GSTSetup."Cess Tax Type" = TaxTransactionValue."Tax Type") then
                                DetailedGSTEntryBuffer."Component Calc. Type" := GSTGroup."Component Calc. Type";
                            GSTBaseValidation.GetTaxComponentRoundingPrecision(DetailedGSTEntryBuffer, TaxTransactionValue);
                            DetailedGSTEntryBuffer.Insert(true);
                        until TaxTransactionValue.Next() = 0;
                end;
            until TransferLine.Next() = 0;
    end;


    local procedure GetGSTAmount(TaxRecordId: RecordID): Decimal
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        GSTSetup: Record "GST Setup";
    begin
        if not GSTSetup.Get() then
            exit;

        TaxTransactionValue.SetCurrentKey("Tax Record ID", "Value Type", "Tax Type", Percent);
        TaxTransactionValue.SetRange("Tax Record ID", TaxRecordId);
        TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
        if GSTSetup."Cess Tax Type" <> '' then
            TaxTransactionValue.SetRange("Tax Type", GSTSetup."GST Tax Type", GSTSetup."Cess Tax Type")
        else
            TaxTransactionValue.SetRange("Tax Type", GSTSetup."GST Tax Type");
        TaxTransactionValue.SetFilter(Percent, '%1', 0);
        if not TaxTransactionValue.IsEmpty() then
            TaxTransactionValue.CalcSums(Amount);

        exit(TaxTransactionValue.Amount);
    end;

    local procedure FillTransferBufferSales(TransferLine: Record "Transfer Line")
    var
        BondedLocation: Record Location;
        TransferHeader: Record "Transfer Header";
        DocTransactionType: Enum "Transaction Type Enum";
        DocumentType: Enum "Document Type Enum";
    begin
        if (TransferLine."GST Group Code" = '') or (TransferLine."HSN/SAC Code" = '') or (TransferLine."Qty. to Ship" = 0) then
            exit;

        Clear(TempTransferBufferStage);
        TransferHeader.Get(TransferLine."Document No.");
        BondedLocation.Get(TransferHeader."Transfer-from Code");
        TempTransferBufferStage."System-Created Entry" := true;
        TempTransferBufferStage."Gen. Prod. Posting Group" := TransferLine."Gen. Prod. Posting Group";
        TempTransferBufferStage."Global Dimension 1 Code" := TransferLine."Shortcut Dimension 1 Code";
        TempTransferBufferStage."Global Dimension 2 Code" := TransferLine."Shortcut Dimension 2 Code";
        TempTransferBufferStage."Dimension Set ID" := TransferLine."Dimension Set ID";
        TempTransferBufferStage."Inventory Posting Group" := TransferLine."Inventory Posting Group";
        TempTransferBufferStage."Item No." := TransferLine."Item No.";
        if not BondedLocation."Bonded warehouse" then begin
            TempTransferBufferStage.Amount := Round(
                RoundTotalGSTAmountQtyFactor(
                    DocTransactionType::Transfer,
                    DocumentType::Quote,
                    TransferLine."Document No.",
                    TransferLine."Line No.",
                    TransferLine."Qty. to Ship" / TransferLine.Quantity,
                    '',
                    false)
            );
            TempTransferBufferStage."GST Amount" := Round(
                RoundTotalGSTAmountQtyFactor(
                    DocTransactionType::Transfer,
                    DocumentType::Quote,
                    TransferLine."Document No.",
                    TransferLine."Line No.",
                    TransferLine."Qty. to Ship" / TransferLine.Quantity,
                    '',
                    false)
            );
        end;

        TempTransferBufferStage.Quantity := TransferLine."Qty. to Ship";
        TempTransferBufferStage."Amount Loaded on Inventory" := Round(TransferLine."Amount Added to Inventory" * TransferLine."Qty. to Ship" / TransferLine.Quantity);
        TempTransferBufferStage."Charges Amount" := Round(TransferLine."Charges to Transfer" * TransferLine."Qty. to Ship" / TransferLine.Quantity);
        TempTransferBufferStage."Excise Amount" := Round(TransferLine.Amount - -TransferCost);
        TempTransferBufferStage.Amount := TempTransferBufferStage.Amount + TempTransferBufferStage."Excise Amount";
        UpdTransferBuffer(TransferLine, TransferLine."Line No.");
    end;

    local procedure UpdTransferBuffer(TransLine: Record "Transfer Line"; SortingNo: Integer)
    var
        DimensionManagement: Codeunit DimensionManagement;
    begin
        TempTransferBufferStage."Dimension Set ID" := TransLine."Dimension Set ID";
        DimensionManagement.UpdateGlobalDimFromDimSetID(
            TempTransferBufferStage."Dimension Set ID",
            TempTransferBufferStage."Global Dimension 1 Code",
            TempTransferBufferStage."Global Dimension 2 Code");

        ApplyFilterOnTempTransferBufferFinal(TempTransferBufferFinal, TempTransferBufferStage);
        if TempTransferBufferFinal.FindFirst() then begin
            TempTransferBufferFinal."Excise Amount" := TempTransferBufferFinal."Excise Amount" + TempTransferBufferStage."Excise Amount";
            TempTransferBufferFinal.Amount := TempTransferBufferFinal.Amount + TempTransferBufferStage.Amount;
            TempTransferBufferFinal."GST Amount" := TempTransferBufferFinal."GST Amount" + TempTransferBufferStage."GST Amount";
            TempTransferBufferFinal.Quantity := TempTransferBufferFinal.Quantity + TempTransferBufferStage.Quantity;
            TempTransferBufferFinal."Amount Loaded on Inventory" := TempTransferBufferFinal."Amount Loaded on Inventory" + TempTransferBufferStage."Amount Loaded on Inventory";
            TempTransferBufferFinal."Charges Amount" := TempTransferBufferFinal."Charges Amount" + TempTransferBufferStage."Charges Amount";
            if not TempTransferBufferStage."System-Created Entry" then
                TempTransferBufferFinal."System-Created Entry" := false;

            TempTransferBufferFinal.Modify();
        end else begin
            TempTransferBufferFinal := TempTransferBufferStage;
            TempTransferBufferFinal."Sorting No." := SortingNo;
            TempTransferBufferFinal.Insert();
        end;
    end;


    local procedure FillGSTPostingBuffer(TransferLine: Record "Transfer Line")
    var
        Location: Record Location;
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        TransferHeader: Record "Transfer Header";
        QFactor: Decimal;
        GSTStateCode: Code[10];
    begin
        TransferHeader.Get(TransferLine."Document No.");
        if (not Location.Get(TransferHeader."Transfer-from Code")) or (Location."Bonded warehouse") then
            exit;

        Location.TestField("State Code");
        GSTStateCode := Location."State Code";

        DetailedGSTEntryBuffer.Reset();
        DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
        DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
        DetailedGSTEntryBuffer.SetRange("Document Type", 0);
        DetailedGSTEntryBuffer.SetRange("Document No.", TransferLine."Document No.");
        DetailedGSTEntryBuffer.SetRange("Line No.", TransferLine."Line No.");
        DetailedGSTEntryBuffer.SetFilter("GST Base Amount", '<>%1', 0);
        DetailedGSTEntryBuffer.SetRange("GST Amount", 0);
        if DetailedGSTEntryBuffer.FindSet() then
            repeat
                TempGSTPostingBufferStage.Type := TempGSTPostingBufferStage.Type::Item;
                TempGSTPostingBufferStage."Global Dimension 1 Code" := TransferLine."Shortcut Dimension 1 Code";
                TempGSTPostingBufferStage."Global Dimension 2 Code" := TransferLine."Shortcut Dimension 2 Code";
                TempGSTPostingBufferStage."Gen. Prod. Posting Group" := TransferLine."Gen. Prod. Posting Group";
                TempGSTPostingBufferStage."GST Group Code" := TransferLine."GST Group Code";
                QFactor := Abs(TransferLine."Qty. to Ship" / TransferLine.Quantity);
                TempGSTPostingBufferStage."GST Base Amount" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", (QFactor * DetailedGSTEntryBuffer."GST Base Amount"));
                TempGSTPostingBufferStage."GST Amount" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", (QFactor * DetailedGSTEntryBuffer."GST Amount"));
                TempGSTPostingBufferStage."GST %" := DetailedGSTEntryBuffer."GST %";
                TempGSTPostingBufferStage."GST Component Code" := DetailedGSTEntryBuffer."GST Component Code";
                if TempGSTPostingBufferStage."GST Amount" <> 0 then
                    TempGSTPostingBufferStage."Account No." := GetGSTPayableAccountNo(GSTStateCode, DetailedGSTEntryBuffer."GST Component Code");
                UpdateGSTPostingBuffer(TransferLine);
            until DetailedGSTEntryBuffer.Next() = 0;
    end;

    local procedure UpdateGSTPostingBuffer(TransferLine: Record "Transfer Line")
    var
        DimensionManagement: Codeunit DimensionManagement;
    begin
        TempGSTPostingBufferStage."Dimension Set ID" := TransferLine."Dimension Set ID";
        DimensionManagement.UpdateGlobalDimFromDimSetID(
            TempGSTPostingBufferStage."Dimension Set ID",
            TempGSTPostingBufferStage."Global Dimension 1 Code",
            TempGSTPostingBufferStage."Global Dimension 2 Code");

        ApplyFilterOnTempGSTPostingBufferFinal(TempGSTPostingBufferFinal, TempGSTPostingBufferStage);
        if TempGSTPostingBufferFinal.FindFirst() then begin
            TempGSTPostingBufferFinal."GST Base Amount" += TempGSTPostingBufferStage."GST Base Amount";
            TempGSTPostingBufferFinal."GST Amount" += TempGSTPostingBufferStage."GST Amount";
            TempGSTPostingBufferFinal."Interim Amount" += TempGSTPostingBufferStage."Interim Amount";
            TempGSTPostingBufferFinal.Modify();
        end else begin
            TempGSTPostingBufferFinal := TempGSTPostingBufferStage;
            TempGSTPostingBufferFinal.Insert();
        end;
    end;

    local procedure ApplyFilterOnTempGSTPostingBufferFinal(
            var TempGSTPostingBufferFinal: Record "GST Posting Buffer";
            var TempGSTPostingBufferStage: Record "GST Posting Buffer")
    begin
        TempGSTPostingBufferFinal.SetRange(Type, TempGSTPostingBufferStage.Type);
        TempGSTPostingBufferFinal.SetRange("Transaction Type", TempGSTPostingBufferStage."Transaction Type");
        TempGSTPostingBufferFinal.SetRange("Global Dimension 1 Code", TempGSTPostingBufferStage."Global Dimension 1 Code");
        TempGSTPostingBufferFinal.SetRange("Global Dimension 2 Code", TempGSTPostingBufferStage."Global Dimension 2 Code");
        TempGSTPostingBufferFinal.SetRange("Dimension Set ID", TempGSTPostingBufferStage."Dimension Set ID");
        TempGSTPostingBufferFinal.SetRange("Account No.", TempGSTPostingBufferStage."Account No.");
        TempGSTPostingBufferFinal.SetRange("Gen. Bus. Posting Group", TempGSTPostingBufferStage."Gen. Bus. Posting Group");
        TempGSTPostingBufferFinal.SetRange("Gen. Prod. Posting Group", TempGSTPostingBufferStage."Gen. Prod. Posting Group");
        TempGSTPostingBufferFinal.SetRange("GST Amount", 0);
    end;

    local procedure GetGSTPayableAccountNo(LocationCode: Code[10]; GSTComponentCode: Code[30]): Code[20]
    var
        GSTPostingSetup: Record "GST Posting Setup";
    begin
        GSTPostingSetup.Reset();
        GSTPostingSetup.SetRange("State Code", LocationCode);
        GSTPostingSetup.SetRange("Component ID", GSTComponentID(GSTComponentCode));
        GSTPostingSetup.FindFirst();
        exit(GSTPostingSetup."Payable Account")
    end;


    local procedure RoundTotalGSTAmountQtyFactor(
        TransactionType: Enum "Transaction Type Enum";
                             DocumentType: Enum "Document Type Enum";
                             DocumentNo: Code[20];
                             LineNo: Integer;
                             QtyFactor: Decimal;
                             CurrencyCode: Code[10];
                             GSTInvoiceRouding: Boolean): Decimal
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        TotalGSTAmount: Decimal;
        Sign: Integer;
    begin
        DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
        DetailedGSTEntryBuffer.SetRange("Transaction Type", TransactionType);
        DetailedGSTEntryBuffer.SetRange("Document Type", DocumentType);
        DetailedGSTEntryBuffer.SetRange("Document No.", DocumentNo);
        DetailedGSTEntryBuffer.SetRange("Line No.", LineNo);
        if DetailedGSTEntryBuffer.FindSet() then
            repeat
                if DetailedGSTEntryBuffer."Amount Loaded on Item" <> 0 then
                    TotalGSTAmount += DetailedGSTEntryBuffer."Amount Loaded on Item" * QtyFactor
                else
                    if DetailedGSTEntryBuffer."GST Input/Output Credit Amount" <> 0 then
                        TotalGSTAmount += DetailedGSTEntryBuffer."GST Input/Output Credit Amount" * QtyFactor;

                if CurrencyCode = '' then
                    if GSTInvoiceRouding then
                        TotalGSTAmount := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", TotalGSTAmount)
                    else
                        TotalGSTAmount := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", TotalGSTAmount);

                if (CurrencyCode <> '') and GSTInvoiceRouding then
                    TotalGSTAmount := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code", TotalGSTAmount);

            until DetailedGSTEntryBuffer.Next() = 0;

        Sign := GSTBaseValidation.GetSignTransfer(DocumentType, TransactionType);
        exit(TotalGSTAmount * Sign);
    end;

    local procedure PostTransLineToGenJnlLine(TransferHeader: Record "Transfer Header"; TransferShptNo: Code[20])
    var
        SourceCodeSetup: Record "Source Code Setup";
        DocTransferType: Enum "Doc Transfer Type";
    begin
        SourceCodeSetup.Get();

        GenJournalLine.Init();
        GenJournalLine."Posting Date" := TransferHeader."Posting Date";
        GenJournalLine.Description := StrSubstNo(TransferShipmentNoLbl, TransferShptNo);
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Invoice;
        GenJournalLine."Document No." := TransferShptNo;
        GenJournalLine."External Document No." := TransferHeader."No.";
        if TempGSTPostingBufferFinal."GST Amount" <> 0 then begin
            GenJournalLine.Validate(Amount, Round(TempGSTPostingBufferFinal."GST Amount"));
            GenJournalLine."Account No." := TempGSTPostingBufferFinal."Account No.";
        end;

        GenJournalLine."VAT Posting" := GenJournalLine."VAT Posting"::"Manual VAT Entry";
        GenJournalLine."GST Group Code" := TempGSTPostingBufferFinal."GST Group Code";
        GenJournalLine."GST Component Code" := TempGSTPostingBufferFinal."GST Component Code";
        GenJournalLine."System-Created Entry" := TempTransferBufferStage."System-Created Entry";
        GenJournalLine."Gen. Bus. Posting Group" := TempGSTPostingBufferFinal."Gen. Bus. Posting Group";
        GenJournalLine."Gen. Prod. Posting Group" := TempGSTPostingBufferFinal."Gen. Prod. Posting Group";
        GenJournalLine."Shortcut Dimension 1 Code" := TempGSTPostingBufferFinal."Global Dimension 1 Code";
        GenJournalLine."Shortcut Dimension 2 Code" := TempGSTPostingBufferFinal."Global Dimension 2 Code";
        GenJournalLine."Dimension Set ID" := TempGSTPostingBufferFinal."Dimension Set ID";
        GenJournalLine."Location Code" := TransferHeader."Transfer-from Code";
        GenJournalLine."Source Code" := SourceCodeSetup.Transfer;
        GenJournalLine."Account Type" := GenJournalLine."Account Type"::"G/L Account";
        RunGenJnlPostLine(GenJournalLine);
        InsertGSTLedgerEntryTransfer(
          TempGSTPostingBufferFinal,
          TransferHeader,
          GenJnlPostLine.GetNextTransactionNo(),
          GenJournalLine."Document No.",
          SourceCodeSetup.Transfer,
          DocTransferType::"Transfer Shipment");
    end;

    local procedure UpdateDetailedGSTLedgerEntryTransfer(
        var DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        DocumentNo: Code[20];
        LineNo: Integer;
        TransactionNo: Integer;
        QtyBase: Decimal;
        QtyShip: Decimal;
        DocTransferType: Enum "Doc Transfer Type")
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
    begin
        DetailedGSTEntryBuffer.SetCurrentKey("Transaction Type", "Document Type", "Document No.", "Line No.");
        DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
        DetailedGSTEntryBuffer.SetRange("Document Type", DetailedGSTEntryBuffer."Document Type"::Quote);
        DetailedGSTEntryBuffer.SetRange("Document No.", DocumentNo);
        DetailedGSTEntryBuffer.SetRange("Line No.", LineNo);
        DetailedGSTEntryBuffer.SetRange("GST Component Code", DetailedGSTLedgerEntry."GST Component Code");
        DetailedGSTEntryBuffer.SetRange("GST Amount", 0);
        if DetailedGSTEntryBuffer.FindFirst() then begin
            DetailedGSTLedgerEntry.Type := DetailedGSTEntryBuffer.Type;
            DetailedGSTLedgerEntry."No." := DetailedGSTEntryBuffer."No.";
            DetailedGSTLedgerEntry."Product Type" := DetailedGSTLedgerEntry."Product Type"::Item;
            DetailedGSTLedgerEntry."HSN/SAC Code" := DetailedGSTEntryBuffer."HSN/SAC Code";
            DetailedGSTLedgerEntry."GST Component Code" := DetailedGSTEntryBuffer."GST Component Code";
            DetailedGSTLedgerEntry."GST Group Code" := DetailedGSTEntryBuffer."GST Group Code";
            DetailedGSTLedgerEntry."Document Line No." := DetailedGSTEntryBuffer."Line No.";
            if DetailedGSTEntryBuffer."GST Assessable Value" <> 0 then begin
                DetailedGSTLedgerEntry."GST Base Amount" := -GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(
                                                                                DetailedGSTEntryBuffer."GST Component Code", (
                                                                                    DetailedGSTEntryBuffer."GST Assessable Value"
                                                                                    + DetailedGSTEntryBuffer."Custom Duty Amount"));
                DetailedGSTLedgerEntry."GST Amount" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
                                                                                                                (DetailedGSTEntryBuffer."GST Amount"));
            end else begin
                DetailedGSTLedgerEntry."GST Base Amount" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
                                                                                                            (DetailedGSTEntryBuffer."GST Base Amount" * QtyShip / QtyBase));
                DetailedGSTLedgerEntry."GST Amount" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
                                                                                                            (DetailedGSTEntryBuffer."GST Amount" * QtyShip / QtyBase));
            end;

            DetailedGSTLedgerEntry."Remaining Base Amount" := 0;
            DetailedGSTLedgerEntry."Remaining GST Amount" := 0;
            DetailedGSTLedgerEntry."GST %" := DetailedGSTEntryBuffer."GST %";
            if DocTransferType = DocTransferType::"Transfer Shipment" then begin
                DetailedGSTLedgerEntry.Quantity := -QtyShip;
                DetailedGSTLedgerEntry."Remaining Quantity" := -QtyShip;
            end else begin
                DetailedGSTLedgerEntry.Quantity := QtyShip;
                DetailedGSTLedgerEntry."Remaining Quantity" := QtyShip;
            end;

            if DocTransferType = DocTransferType::"Transfer Receipt" then
                if DetailedGSTEntryBuffer."GST Assessable Value" <> 0 then
                    DetailedGSTLedgerEntry."Amount Loaded on Item" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
                                                                                                                            DetailedGSTEntryBuffer."Amount Loaded on Item")
                else
                    DetailedGSTLedgerEntry."Amount Loaded on Item" := GSTBaseValidation.RoundGSTPrecisionThroughTaxComponent(DetailedGSTEntryBuffer."GST Component Code",
                                                                                                    (DetailedGSTEntryBuffer."Amount Loaded on Item" * QtyShip / QtyBase))
            else
                DetailedGSTLedgerEntry."Amount Loaded on Item" := 0;

            if DocTransferType = DocTransferType::"Transfer Receipt" then begin
                if DetailedGSTLedgerEntry."Amount Loaded on Item" <> 0 then
                    DetailedGSTLedgerEntry."GST Credit" := DetailedGSTLedgerEntry."GST Credit"::"Non-Availment"
                else
                    DetailedGSTLedgerEntry."GST Credit" := DetailedGSTLedgerEntry."GST Credit"::Availment;

                DetailedGSTLedgerEntry."Credit Availed" := GetReceivableApplicable(
                DetailedGSTLedgerEntry."GST Vendor Type",
                DetailedGSTLedgerEntry."GST Group Type",
                DetailedGSTLedgerEntry."GST Credit", false, false);
            end;

            if DocTransferType = DocTransferType::"Transfer Receipt" then
                ReverseDetailedGSTEntryQtyAmt(DetailedGSTLedgerEntry);

            DetailedGSTLedgerEntry."GST Rounding Type" := DetailedGSTEntryBuffer."GST Rounding Type";
            DetailedGSTLedgerEntry."GST Rounding Precision" := DetailedGSTEntryBuffer."GST Rounding Precision";
            DetailedGSTLedgerEntry."GST Inv. Rounding Type" := DetailedGSTEntryBuffer."GST Inv. Rounding Type";
            DetailedGSTLedgerEntry."GST Inv. Rounding Precision" := DetailedGSTEntryBuffer."GST Inv. Rounding Precision";
            DetailedGSTLedgerEntry."Transaction No." := TransactionNo;
            if DetailedGSTLedgerEntry."GST Credit" = DetailedGSTLedgerEntry."GST Credit"::"Non-Availment" then
                DetailedGSTLedgerEntry."Eligibility for ITC" := DetailedGSTLedgerEntry."Eligibility for ITC"::Ineligible
            else
                if DetailedGSTLedgerEntry."GST Credit" = DetailedGSTLedgerEntry."GST Credit"::Availment then
                    if DetailedGSTLedgerEntry."GST Group Type" = DetailedGSTLedgerEntry."GST Group Type"::Service then
                        DetailedGSTLedgerEntry."Eligibility for ITC" := DetailedGSTLedgerEntry."Eligibility for ITC"::"Input Services"
                    else
                        if DetailedGSTLedgerEntry.Type = DetailedGSTLedgerEntry.Type::"Fixed Asset" then
                            DetailedGSTLedgerEntry."Eligibility for ITC" := DetailedGSTLedgerEntry."Eligibility for ITC"::"Capital goods"
                        else
                            DetailedGSTLedgerEntry."Eligibility for ITC" := DetailedGSTLedgerEntry."Eligibility for ITC"::Inputs;
        end;
    end;

    local procedure ReverseDetailedGSTEntryQtyAmt(var DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry")
    begin
        DetailedGSTLedgerEntry."GST Base Amount" := -DetailedGSTLedgerEntry."GST Base Amount";
        DetailedGSTLedgerEntry."GST Amount" := -DetailedGSTLedgerEntry."GST Amount";
        DetailedGSTLedgerEntry."Amount Loaded on Item" := -DetailedGSTLedgerEntry."Amount Loaded on Item";
    end;

    local procedure GetReceivableApplicable(
        GSTVendorType: Enum "GST Vendor Type";
                           GSTGroupType: Enum "GST Group Type";
                           GSTCredit: Enum "GST Credit";
                           AssociatedEnterprises: Boolean;
                           ReverseCharge: Boolean): Boolean
    begin
        if GSTCredit = GSTCredit::Availment then
            case GSTVendorType of
                GSTVendorType::Registered:
                    begin
                        if ReverseCharge then
                            exit(false);

                        exit(true);
                    end;
                GSTVendorType::Unregistered:
                    if GSTGroupType = GSTGroupType::Goods then
                        exit(true);
                GSTVendorType::Import, GSTVendorType::SEZ:
                    begin
                        if (GSTGroupType = GSTGroupType::Service) and not ReverseCharge then
                            exit(true);

                        if GSTGroupType = GSTGroupType::Goods then
                            exit(true);

                        exit(AssociatedEnterprises = true);
                    end;
            end;
    end;

    local procedure GetFromEntryNo(DocumentNo: Code[20]; LineNo: Integer; OrignalDocType: Enum "Original Doc Type"): Integer
    var
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        DetailedGSTLedgerEntryInfo: Record "Detailed GST Ledger Entry Info";
    begin
        DetailedGSTLedgerEntry.SetRange("Document No.", DocumentNo);
        DetailedGSTLedgerEntry.SetRange("Document Line No.", LineNo);
        DetailedGSTLedgerEntry.SetRange("Transaction Type", DetailedGSTLedgerEntry."Transaction Type"::Purchase);
        DetailedGSTLedgerEntry.SetRange("Entry Type", DetailedGSTLedgerEntry."Entry Type"::"Initial Entry");
        if DetailedGSTLedgerEntry.FindFirst() then
            if DetailedGSTLedgerEntryInfo.Get(DetailedGSTLedgerEntry."Entry No.") then
                if DetailedGSTLedgerEntryInfo."Original Doc. Type" = OrignalDocType then
                    exit(DetailedGSTLedgerEntryInfo."Entry No.");

        exit(1);
    end;

    local procedure GetToEntryNo(DocumentNO: Code[20]; LineNo: Integer; OrignalDocType: Enum "Original Doc Type"): Integer
    var
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        DetailedGSTLedgerEntryInfo: Record "Detailed GST Ledger Entry Info";
    begin
        DetailedGSTLedgerEntry.SetRange("Document No.", DocumentNO);
        DetailedGSTLedgerEntry.SetRange("Document Line No.", LineNo);
        DetailedGSTLedgerEntry.SetRange("Transaction Type", DetailedGSTLedgerEntry."Transaction Type"::Purchase);
        DetailedGSTLedgerEntry.SetRange("Entry Type", DetailedGSTLedgerEntry."Entry Type"::"Initial Entry");
        if DetailedGSTLedgerEntry.FindLast() then
            if DetailedGSTLedgerEntryInfo.Get(DetailedGSTLedgerEntry."Entry No.") then
                if DetailedGSTLedgerEntryInfo."Original Doc. Type" = OrignalDocType then
                    exit(DetailedGSTLedgerEntryInfo."Entry No.");

        exit(1);
    end;

    local procedure RunGenJnlPostLine(var GenJnlLine: Record "Gen. Journal Line")
    begin
        GenJnlPostLine.RunWithCheck(GenJnlLine);
    end;

    local procedure GETGSTJurisdictionType(TransferHeader: Record "Transfer Header"): Enum "GST Jurisdiction Type"
    var
        Location: Record Location;
        Location2: Record Location;
        GSTJurisdictionType: Enum "GST Jurisdiction Type";
    begin
        Location.Get(TransferHeader."Transfer-from Code");
        Location2.Get(TransferHeader."Transfer-to Code");
        if Location."State Code" <> Location2."State Code" then
            exit(GSTJurisdictionType::Interstate)
        else
            exit(GSTJurisdictionType::Intrastate);
    end;

    local procedure GetTransferShipmentPostingNoSeries(var TransferHeader: Record "Transfer Header"): Code[20]
    var
        PostingNoSeries: Record "Posting No. Series";
        NoSeriesCode: Code[20];
    begin
        PostingNoSeries.SetRange("Table Id", Database::"Transfer Header");
        NoSeriesCode := LoopPostingNoSeries(PostingNoSeries, TransferHeader, PostingNoSeries."Document Type"::"Transfer Shipment Header");
        exit(NoSeriesCode);
    end;

    local procedure RecordViewFound(Record: Variant; Filters: Text) Found: Boolean;
    var
        Field: Record Field;
        DuplicateRecRef: RecordRef;
        TempRecRef: RecordRef;
        FieldRef: FieldRef;
        TempFieldRef: FieldRef;
    begin
        DuplicateRecRef.GetTable(Record);
        Clear(TempRecRef);
        TempRecRef.Open(DuplicateRecRef.Number(), true);
        Field.SetRange(TableNo, DuplicateRecRef.Number());
        if Field.FindSet() then
            repeat
                FieldRef := DuplicateRecRef.Field(Field."No.");
                TempFieldRef := TempRecRef.Field(Field."No.");
                TempFieldRef.Value := FieldRef.Value();
            until Field.Next() = 0;

        TempRecRef.Insert();
        Found := true;
        if Filters = '' then
            exit;

        TempRecRef.SetView(Filters);
        Found := TempRecRef.Find();
    end;

    local procedure GetRecordView(var PostingNoSeries: Record "Posting No. Series") Filters: Text;
    var
        ConditionInStream: InStream;
    begin
        PostingNoSeries.CalcFields(Condition);
        PostingNoSeries.Condition.CreateInStream(ConditionInStream);
        ConditionInStream.Read(Filters);
    end;

    local procedure ClearBuffers()
    begin
        ClearAll();
        TempTransferBufferStage.DeleteAll();
        TempTransferBufferFinal.DeleteAll();
        TempGSTPostingBufferStage.DeleteAll();
        TempGSTPostingBufferFinal.DeleteAll();
    end;

    local procedure FillDetailedGSTLedgerEntryShipment(
        Var DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        Location: Record Location;
        Location2: Record Location;
        TransferHeader: Record "Transfer Header")
    begin
        DetailedGSTLedgerEntry."Location Code" := Location.Code;
        DetailedGSTLedgerEntry."Location  Reg. No." := Location."GST Registration No.";
        DetailedGSTLedgerEntry."Buyer/Seller Reg. No." := Location2."GST Registration No.";
        DetailedGSTLedgerEntry."External Document No." := TransferHeader."No.";
        DetailedGSTLedgerEntry."GST Customer Type" := "GST Customer Type"::Registered;
        DetailedGSTLedgerEntry."Liable to Pay" := true;
    end;

    local procedure FillDetailedGSTLedgerEntryReceipt(
        Var DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        Location: Record Location;
        Location2: Record Location;
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line")
    begin
        DetailedGSTLedgerEntry."Location Code" := Location2.Code;
        DetailedGSTLedgerEntry."Location  Reg. No." := Location2."GST Registration No.";
        DetailedGSTLedgerEntry."Buyer/Seller Reg. No." := Location."GST Registration No.";
        DetailedGSTLedgerEntry."External Document No." := TransferHeader."Last Shipment No.";
        DetailedGSTLedgerEntry."GST VEndor Type" := "GST VEndor Type"::Registered;
        if Location."Bonded warehouse" then begin
            DetailedGSTLedgerEntry."GST VEndor Type" := "GST VEndor Type"::Import;
            DetailedGSTLedgerEntry."Credit Availed" := true;
            DetailedGSTLedgerEntry."Reverse Charge" := true;
            DetailedGSTLedgerEntry."Buyer/Seller Reg. No." := '';
            DetailedGSTLedgerEntry."Source Type" := "Source Type"::VEndor;
            DetailedGSTLedgerEntry."Source No." := TransferHeader."VEndor No.";
            DetailedGSTLedgerEntry."GST Assessable Value" := TransferLine."GST Assessable Value";
            DetailedGSTLedgerEntry."Custom Duty Amount" := TransferLine."Custom Duty Amount";
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnAfterInsertTransShptLine', '', false, false)]
    local procedure InsertDetailedGSTEntry(TransLine: Record "Transfer Line"; var TransShptLine: Record "Transfer Shipment Line")
    var
        TransferHeader: Record "Transfer Header";
        Location: Record Location;
        DocTransferType: Enum "Doc Transfer Type";
    begin
        FillTransferBufferSales(TransLine);
        TransferHeader.Get(TransLine."Document No.");
        // FillDetailLedgBufferTransferSales(TransferHeader."No.");
        Location.Get(TransferHeader."Transfer-from Code");
        if not Location."Bonded warehouse" then
            InsertDetailedGSTLedgEntryTransfer(TransLine, TransferHeader, TransShptLine."Document No.", GenJnlPostLine.GetNextTransactionNo(), DocTransferType::"Transfer Shipment");
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnRunOnBeforeCommit', '', false, false)]
    local procedure PostGLEntriesShipment(var TransferHeader: Record "Transfer Header"; TransferShipmentHeader: Record "Transfer Shipment Header")
    var
        InventoryPostingSetup: Record "Inventory Posting Setup";
        TransferLine: Record "Transfer Line";
        IsHandled: Boolean;
    begin
        // Post GST to G/L entries from GST posting buffer.. GST Sales
        TempGSTPostingBufferFinal.Reset();
        TempGSTPostingBufferFinal.SetCurrentKey(
            "Transaction Type",
            Type,
            "Gen. Bus. Posting Group",
            "Gen. Prod. Posting Group",
            "GST Component Code",
            "GST Group Type",
            "Account No.",
            "Dimension Set ID",
            "GST Reverse Charge",
            Availment,
            "Normal Payment",
            "Forex Fluctuation",
            "Document Line No.");
        TempGSTPostingBufferFinal.SetAscending("Document Line No.", false);
        TempGSTPostingBufferFinal.SetRange("GST Amount", 0);
        if TempGSTPostingBufferFinal.FindSet() then
            repeat
                PostTransLineToGenJnlLine(TransferHeader, TransferShipmentHeader."No.");
            until TempGSTPostingBufferFinal.Next() = 0;




    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnBeforeTransferOrderPostShipment', '', False, False)]
    local procedure FillGSTLedgerBufferShip(var TransferHeader: Record "Transfer Header")
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";

    begin
        ClearBuffers();
        GSTBaseValidation.CheckGSTAccountingPeriod(TransferHeader."Posting Date", false);
        DetailedGSTEntryBuffer.SetRange("Document Type", DetailedGSTEntryBuffer."Document Type"::Quote);
        DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
        DetailedGSTEntryBuffer.SetRange("Document No.", TransferHeader."No.");
        DetailedGSTEntryBuffer.SetRange("GST Amount", 0);
        if DetailedGSTEntryBuffer.FindFirst() then
            DetailedGSTEntryBuffer.DeleteAll(true);

        FillDetailLedgBufferTransferSales(TransferHeader."No.");
    end;

    // [EventSubscriber(ObjectType::Table, Database::"Transfer Shipment Header", 'OnAfterCopyFromTransferHeader', '', False, False)]
    // local procedure CopyInfointoTransShptHeader(TransferHeader: Record "Transfer Header"; var TransferShipmentHeader: Record "Transfer Shipment Header")
    // begin
    //     TransferShipmentHeader."Time of Removal" := TransferHeader."Time of Removal";
    //     TransferShipmentHeader."Vehicle No." := TransferHeader."Vehicle No.";
    //     TransferShipmentHeader."LR/RR No." := TransferHeader."LR/RR No.";
    //     TransferShipmentHeader."LR/RR Date" := TransferHeader."LR/RR Date";
    //     TransferShipmentHeader."Mode of Transport" := TransferHeader."Mode of Transport";
    //     TransferShipmentHeader."Distance (Km)" := TransferHeader."Distance (Km)";
    //     TransferShipmentHeader."Vehicle Type" := TransferHeader."Vehicle Type";
    // end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Shipment", 'OnBeforeInsertTransShptLine', '', False, False)]
    local procedure FillBuffer(var TransShptLine: Record "Transfer Shipment Line"; TransLine: Record "Transfer Line")
    var
        GSTGroup: Record "GST Group";
        IsHandled: Boolean;
    begin

        if GSTGroup.Get(TransLine."GST Group Code") and (GSTGroup."GST Group Type" <> GSTGroup."GST Group Type"::Goods) then
            Error(GSTGroupServiceErr);

        if (TransLine."Qty. to Ship" <> 0) and (GetGSTAmount(TransLine.RecordId) = 0) then
            FillGSTPostingBuffer(TransLine);
    end;

    local procedure PostGeneralEntries(
        var TempTransferBufferFinal: Record "Transfer Buffer";
        var TransferShipmentHeader: Record "Transfer Shipment Header";
        var TransferHeader: Record "Transfer Header";
        var InventoryPostingSetup: Record "Inventory Posting Setup")
    begin
        GenJournalLine.Init();
        GenJournalLine."Posting Date" := TransferHeader."Posting Date";
        GenJournalLine."Document Date" := TransferHeader."Posting Date";
        GenJournalLine."Document No." := TransferShipmentHeader."No.";
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Invoice;
        GenJournalLine."Account No." := InventoryPostingSetup."Unrealized Profit Account";
        GenJournalLine."System-Created Entry" := TempTransferBufferFinal."System-Created Entry";
        GenJournalLine.Amount := TempTransferBufferFinal.Amount + TempTransferBufferFinal."Charges Amount";
        GenJournalLine.Quantity := TempTransferBufferFinal.Quantity;
        GenJournalLine."Shortcut Dimension 1 Code" := TempTransferBufferFinal."Global Dimension 1 Code";
        GenJournalLine."Shortcut Dimension 2 Code" := TempTransferBufferFinal."Global Dimension 2 Code";
        GenJournalLine."Dimension Set ID" := TempTransferBufferFinal."Dimension Set ID";
        GenJournalLine.Description := StrSubstNo(TransferShipmentNoLbl, TransferShipmentHeader."No.");
        if GenJournalLine.Amount <> 0 then
            RunGenJnlPostLine(GenJournalLine);

        GenJournalLine.Init();
        GenJournalLine."Posting Date" := TransferHeader."Posting Date";
        GenJournalLine."Document Date" := TransferHeader."Posting Date";
        GenJournalLine."Document No." := TransferShipmentHeader."No.";
        GenJournalLine."Document Type" := GenJournalLine."Document Type"::Invoice;
        GenJournalLine."Account No." := InventoryPostingSetup."Unrealized Profit Account";
        GenJournalLine."System-Created Entry" := TempTransferBufferFinal."System-Created Entry";
        GenJournalLine.Amount := -TempTransferBufferFinal."Excise Amount";
        GenJournalLine."Shortcut Dimension 1 Code" := TempTransferBufferFinal."Global Dimension 1 Code";
        GenJournalLine."Shortcut Dimension 2 Code" := TempTransferBufferFinal."Global Dimension 2 Code";
        GenJournalLine."Dimension Set ID" := TempTransferBufferFinal."Dimension Set ID";
        GenJournalLine.Description := STRSUBSTNO(TransferShipmentNoLbl, TransferShipmentHeader."No.");
        if GenJournalLine."Amount" <> 0 then
            RunGenJnlPostLine(GenJournalLine);
    end;

    procedure UpdateGSTTrackingEntryFromTransferOrder(DocumentNo: Code[20]; ItemNo: Code[20]; DocumentLineNo: Integer; OrignalDocType: Enum "Original Doc Type")
    var
        GSTTrackingEntry: Record "GST Tracking Entry";
        ItemLedgerEntry: Record "Item Ledger Entry";
        IsHandled: Boolean;
    begin

        ItemLedgerEntry.SetRange("Document No.", DocumentNo);
        ItemLedgerEntry.SetRange("Item No.", ItemNo);
        ItemLedgerEntry.SetRange(Open, true);
        if ItemLedgerEntry.FindSet() then
            repeat
                GSTTrackingEntry.Init();
                GSTTrackingEntry."Entry No." := 0;
                GSTTrackingEntry."From Entry No." := GetFromEntryNo(DocumentNo, DocumentLineNo, OrignalDocType);
                GSTTrackingEntry."From To No." := GetToEntryNo(DocumentNo, DocumentLineNo, OrignalDocType);
                GSTTrackingEntry."Item Ledger Entry No." := ItemLedgerEntry."Entry No.";
                GSTTrackingEntry.Quantity := ItemLedgerEntry.Quantity;
                GSTTrackingEntry."Remaining Quantity" := ItemLedgerEntry."Remaining Quantity";
                GSTTrackingEntry.Insert(true);
            until ItemLedgerEntry.Next() = 0;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"TransferOrder-Post Receipt", 'OnBeforeTransRcptHeaderInsert', '', true, true)]
    local procedure "TransferOrder-Post Receipt_OnBeforeTransRcptHeaderInsert"
    (
        var TransferReceiptHeader: Record "Transfer Receipt Header";
        TransferHeader: Record "Transfer Header"
    )
    var
        DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        TaxTransactionValue: Record "Tax Transaction Value";
        TransferLine: Record "Transfer Line";
        Item: Record Item;
        GSTSetup: Record "GST Setup";
    begin
        if not GSTSetup.Get() then
            exit;
        //  ClearBuffers();
        TransferLine.Reset();
        TransferLine.SetRange("Document No.", TransferHeader."No.");
        if TransferLine.FindSet() then
            repeat
                if TransferLine."Item No." <> '' then begin
                    TransferLine.TestField(Quantity);
                    Item.Get(TransferLine."Item No.");
                    TaxTransactionValue.Reset();
                    TaxTransactionValue.SetRange("Tax Type", GSTSetup."GST Tax Type");
                    TaxTransactionValue.SetRange("Tax Record ID", TransferLine.RecordId);
                    TaxTransactionValue.SetRange("Value Type", TaxTransactionValue."Value Type"::COMPONENT);
                    TaxTransactionValue.SetFilter(Percent, '%1', 0);
                    if TaxTransactionValue.FindSet() then
                        repeat
                            DetailedGSTEntryBuffer.SetRange("Document Type", DetailedGSTEntryBuffer."Document Type"::Quote);
                            DetailedGSTEntryBuffer.SetRange("Transaction Type", DetailedGSTEntryBuffer."Transaction Type"::Transfer);
                            DetailedGSTEntryBuffer.SetRange("Document No.", TransferHeader."No.");
                            if DetailedGSTEntryBuffer.FindFirst() then
                                DetailedGSTEntryBuffer.DeleteAll(true);
                        until TaxTransactionValue.Next() = 0;
                end;
            until TransferLine.Next() = 0;

        FillDetailLedgBufferTransfer(TransferHeader."No.");
    end;

    local procedure FillDetailedGSTEntryBuffer(
        var DetailedGSTEntryBuffer: Record "Detailed GST Entry Buffer";
        TransferHeader: Record "Transfer Header";
        Item: Record Item;
        TransferLine: Record "Transfer Line";
        TaxTransactionValue: Record "Tax Transaction value")
    var
        GeneralLedgerSetup: Record "General Ledger Setup";
        DocumentType: Enum "Document Type Enum";
        TransactionType: Enum "Transaction Type Enum";
        Sign: Integer;
        GSTbaseValidation: codeunit "GST Base Validation";
    begin
        GeneralLedgerSetup.Get();
        Sign := GSTbaseValidation.GetSignTransfer(DocumentType::Quote, TransactionType::"Transfer");

        DetailedGSTEntryBuffer.Init();
        DetailedGSTEntryBuffer."Entry No." := 0;
        DetailedGSTEntryBuffer."Document Type" := DetailedGSTEntryBuffer."Document Type"::Quote;
        DetailedGSTEntryBuffer."Document No." := TransferHeader."No.";
        DetailedGSTEntryBuffer."Posting Date" := TransferHeader."Posting Date";
        DetailedGSTEntryBuffer."Transaction Type" := DetailedGSTEntryBuffer."Transaction Type"::transfer;
        DetailedGSTEntryBuffer.Type := DetailedGSTEntryBuffer.Type::Item;
        DetailedGSTEntryBuffer.UOM := Item."Base Unit of Measure";
        DetailedGSTEntryBuffer."No." := TransferLine."Item No.";
        DetailedGSTEntryBuffer."Source No." := '';
        DetailedGSTEntryBuffer.Quantity := TransferLine.Quantity * Sign;
        DetailedGSTEntryBuffer."HSN/SAC Code" := TransferLine."HSN/SAC Code";
        DetailedGSTEntryBuffer.Exempted := TransferLine.Exempted;
        DetailedGSTEntryBuffer."Location Code" := TransferHeader."Transfer-from Code";
        DetailedGSTEntryBuffer."Line No." := TransferLine."Line No.";
        DetailedGSTEntryBuffer."Source Type" := "Source Type"::" ";
        DetailedGSTEntryBuffer."GST Input/Output Credit Amount" := Sign * TaxTransactionValue.Amount;
        DetailedGSTEntryBuffer."GST Base Amount" := Sign * TransferLine.Amount;
        DetailedGSTEntryBuffer."GST %" := TaxTransactionValue.Percent;
        DetailedGSTEntryBuffer."GST Rounding Precision" := GeneralLedgerSetup."Inv. Rounding Precision (LCY)";
        DetailedGSTEntryBuffer."GST Rounding Type" := GSTBaseValidation.GenLedInvRoundingType2GSTInvRoundingTypeEnum(GeneralLedgerSetup."Inv. Rounding Type (LCY)");
        DetailedGSTEntryBuffer."GST Inv. Rounding Precision" := GeneralLedgerSetup."Inv. Rounding Precision (LCY)";
        DetailedGSTEntryBuffer."GST Inv. Rounding Type" := GSTBaseValidation.GenLedInvRoundingType2GSTInvRoundingTypeEnum(GeneralLedgerSetup."Inv. Rounding Type (LCY)");
        DetailedGSTEntryBuffer."Currency Factor" := 1;
        DetailedGSTEntryBuffer."GST Amount" := Sign * TaxTransactionValue.Amount;
        DetailedGSTEntryBuffer."Custom Duty Amount" := TransferLine."Custom Duty Amount";
        DetailedGSTEntryBuffer."GST Assessable Value" := TransferLine."GST Assessable Value";
        if TransferLine."GST Credit" = TransferLine."GST Credit"::"Non-Availment" then begin
            DetailedGSTEntryBuffer."Amount Loaded on Item" := Sign * TaxTransactionValue.Amount;
            DetailedGSTEntryBuffer."Non-Availment" := true;
        end else
            DetailedGSTEntryBuffer."GST Input/Output Credit Amount" := Sign * TaxTransactionValue.Amount;

        DetailedGSTEntryBuffer."GST Component Code" := GetGSTComponent(TaxTransactionValue."Value ID");
        DetailedGSTEntryBuffer."GST Group Code" := TransferLine."GST Group Code";
        DetailedGSTEntryBuffer.Insert(true);
    end;


    procedure UndoTransferShipment(TransShptLine1: Record "Transfer Shipment Line")
    var
        PostedWhseShptLine: Record "Posted Whse. Shipment Line";
        TransferLine: Record "Transfer Line";

        WhseJnlRegisterLine: Codeunit "Whse. Jnl.-Register Line";
        Window: Dialog;
        ItemShptEntryNo: Integer;
        DocLineNo: Integer;
        Direction: Enum "Transfer Direction";
        PostedWhseShptLineFound: Boolean;
        TransShptLine: Record "Transfer Shipment Line";
        fromLoc: Record Location;
        ToLOC: Record Location;

    begin
        Clear(ItemJnlPostLine);
        TransShptLine.Reset();
        TransShptLine.SetCurrentKey("Item Shpt. Entry No.");
        TransShptLine.SetRange("Document No.", TransShptLine1."Document No.");
        TransShptLine.SetRange("Line No.", TransShptLine1."Line No.");
        TransShptLine.SetFilter(Quantity, '<>0');

        TransShptLine.SetRange("Correction Line", false);
        //OnCodeOnAfterTransShptLineSetFilters(TransShptLine);

        if TransShptLine.IsEmpty() then
            Error(AlreadyReversedErr);
        TransShptLine.FindSet();
        repeat
            fromLoc.Get(TransShptLine."Transfer-from Code");
            ToLOC.Get(TransShptLine."Transfer-to Code");
            if fromLoc."State Code" <> ToLOC."State Code" then
                Error('You Can not undo Interstate Transaction');
            TransferLine.Reset();
            TransferLine.SetRange("Document No.", TransShptLine."Transfer Order No.");
            TransferLine.SetRange("Line No.", TransShptLine."Trans. Order Line No.");
            if not TransferLine.FindFirst() then
                Error('Transfer Order has been Received');
            CheckTransferShptLine(TransShptLine);
        until TransShptLine.Next() = 0;

        TransShptLine.FindSet();
        repeat
            //OnCodeOnBeforeUndoLoop(TransShptLine);
            if TransShptLine."Trans. Order Line No." = 0 then
                Error(NoTransOrderLineNoErr);
            TransferLine.Get(TransShptLine."Transfer Order No.", TransShptLine."Trans. Order Line No.");
            if TransferLine."Qty. Received (Base)" > 0 then
                Error(AlreadyReceivedErr);
            if TransShptLine."Derived Trans. Order Line No." = 0 then
                Error(NoDerivedTransOrderLineNoErr);

            TempGlobalItemLedgEntry.Reset();
            if not TempGlobalItemLedgEntry.IsEmpty() then
                TempGlobalItemLedgEntry.DeleteAll();
            TempGlobalItemEntryRelation.Reset();
            if not TempGlobalItemEntryRelation.IsEmpty() then
                TempGlobalItemEntryRelation.DeleteAll();

            // if not HideDialog then
            //     Window.Open(UndoQtyMsg);

            PostedWhseShptLineFound :=
             WhseUndoQty.FindPostedWhseShptLine(
                 PostedWhseShptLine, Database::"Transfer Shipment Line", TransShptLine."Document No.",
                 Database::"Transfer Line", Direction::Outbound.AsInteger(), TransShptLine."Transfer Order No.", TransShptLine."Line No.");

            // Undo derived transfer line and move tracking to current line
            UpdateDerivedTransferLine(TransferLine, TransShptLine);

            Clear(ItemJnlPostLine);
            ItemShptEntryNo := PostItemJnlLineTransfer(TransShptLine, DocLineNo);
            InsertNewTransferShipmentLine(TransShptLine, ItemShptEntryNo, DocLineNo);
            //OnAfterInsertNewShipmentLine(TransShptLine, PostedWhseShptLine, PostedWhseShptLineFound, DocLineNo);

            if PostedWhseShptLineFound then
                WhseUndoQty.UndoPostedWhseShptLine(PostedWhseShptLine);

            TempWhseJnlLine.SetRange("Source Line No.", TransShptLine."Line No.");
            WhseUndoQty.PostTempWhseJnlLineCache(TempWhseJnlLine, WhseJnlRegisterLine);

            UndoTransferShipmentCod.UpdateOrderLine(TransShptLine);
            if PostedWhseShptLineFound then
                WhseUndoQty.UpdateShptSourceDocLines(PostedWhseShptLine);

            TransShptLine."Correction Line" := true;
            //OnBeforeModifyTransShptLine(TransShptLine);
            TransShptLine.Modify();

        until TransShptLine.Next() = 0;

        MakeInventoryAdjustment();
        //OnAfterCode(TransShptLine);
    end;

    local procedure InsertNewTransferShipmentLine(OldTransShptLine: Record "Transfer Shipment Line"; ItemShptEntryNo: Integer; DocLineNo: Integer)
    var
        NewTransShptLine: Record "Transfer Shipment Line";
    begin
        NewTransShptLine.Init();
        NewTransShptLine.Copy(OldTransShptLine);
        NewTransShptLine."Derived Trans. Order Line No." := 0;
        NewTransShptLine."Line No." := DocLineNo;
        NewTransShptLine."Item Shpt. Entry No." := ItemShptEntryNo;
        NewTransShptLine.Quantity := -OldTransShptLine.Quantity;
        NewTransShptLine."Quantity (Base)" := -OldTransShptLine."Quantity (Base)";
        NewTransShptLine."Correction Line" := true;
        NewTransShptLine."Dimension Set ID" := OldTransShptLine."Dimension Set ID";
        //OnBeforeInsertNewTransShptLine(NewTransShptLine, OldTransShptLine);
        NewTransShptLine.Insert();

        InsertItemEntryRelation(TempGlobalItemEntryRelation, NewTransShptLine, OldTransShptLine."Trans. Order Line No.");
    end;

    local procedure InsertItemEntryRelation(var TempItemEntryRelation: Record "Item Entry Relation" temporary; NewTransShptLine: Record "Transfer Shipment Line"; OrderLineNo: Integer)
    var
        ItemEntryRelation: Record "Item Entry Relation";
    begin
        if TempItemEntryRelation.FindFirst() then
            repeat
                ItemEntryRelation := TempItemEntryRelation;
                ItemEntryRelation.TransferFieldsTransShptLine(NewTransShptLine);
                ItemEntryRelation."Order Line No." := OrderLineNo;
                ItemEntryRelation.Insert();
            until TempItemEntryRelation.Next() = 0;
    end;

    local procedure PostItemJnlLineTransfer(TransShptLine: Record "Transfer Shipment Line"; var DocLineNo: Integer): Integer
    var
        ItemJnlLine: Record "Item Journal Line";
        TransShptHeader: Record "Transfer Shipment Header";
        SourceCodeSetup: Record "Source Code Setup";
        TempApplyToEntryList: Record "Item Ledger Entry" temporary;
        TempDummyItemEntryRelation: Record "Item Entry Relation" temporary;
        ItemLedgEntry: Record "Item Ledger Entry";
        Direction: Enum "Transfer Direction";
    begin
        DocLineNo := UndoTransferShipmentCod.GetCorrectionLineNo(TransShptLine);

        SourceCodeSetup.Get();
        TransShptHeader.Get(TransShptLine."Document No.");

        ItemJnlLine.Init();
        ItemJnlLine."Entry Type" := ItemJnlLine."Entry Type"::Transfer;
        ItemJnlLine."Order Type" := ItemJnlLine."Order Type"::Transfer;
        ItemJnlLine."Item No." := TransShptLine."Item No.";
        ItemJnlLine."Posting Date" := TransShptHeader."Posting Date";
        ItemJnlLine."Document No." := TransShptLine."Document No.";
        ItemJnlLine."Document Line No." := DocLineNo;
        ItemJnlLine."Gen. Prod. Posting Group" := TransShptLine."Gen. Prod. Posting Group";
        ItemJnlLine."Inventory Posting Group" := TransShptLine."Inventory Posting Group";
        ItemJnlLine."Location Code" := TransShptLine."Transfer-from Code";
        ItemJnlLine."Source Code" := SourceCodeSetup.Transfer;
        ItemJnlLine.Correction := true;
        ItemJnlLine."Variant Code" := TransShptLine."Variant Code";
        ItemJnlLine."Bin Code" := TransShptLine."Transfer-from Bin Code";
        ItemJnlLine."Document Date" := TransShptHeader."Shipment Date";
        ItemJnlLine."Unit of Measure Code" := TransShptLine."Unit of Measure Code";

        //OnAfterCopyItemJnlLineFromTransShpt(ItemJnlLine, TransShptHeader, TransShptLine);

        WhseUndoQty.InsertTempWhseJnlLine(
                       ItemJnlLine,
                       Database::"Transfer Line", Direction::Outbound.AsInteger(), TransShptLine."Transfer Order No.", TransShptLine."Line No.",
                       TempWhseJnlLine."Reference Document"::"Posted T. Shipment".AsInteger(), TempWhseJnlLine, NextLineNo);

        if GetShptEntries(TransShptLine, ItemLedgEntry) then begin
            ItemLedgEntry.SetTrackingFilterBlank();
            if ItemLedgEntry.FindSet() then begin
                // First undo In-Transit item ledger entries
                ItemLedgEntry.SetRange("Location Code", TransShptHeader."In-Transit Code");
                ItemLedgEntry.FindSet();
                PostCorrectiveItemLedgEntries(ItemJnlLine, ItemLedgEntry);

                // Then undo from-location item ledger entries
                ItemLedgEntry.SetRange("Location Code", TransShptHeader."Transfer-from Code");
                ItemLedgEntry.FindSet();
                PostCorrectiveItemLedgEntries(ItemJnlLine, ItemLedgEntry);

                exit(ItemJnlLine."Item Shpt. Entry No.");
            end
            else begin
                ItemLedgEntry.ClearTrackingFilter();
                ItemLedgEntry.FindSet();
                MoveItemLedgerEntriesToTempRec(ItemLedgEntry, TempApplyToEntryList);
                // First undo In-Transit item ledger entries
                TempApplyToEntryList.SetRange("Location Code", TransShptHeader."In-Transit Code");
                TempApplyToEntryList.FindSet();
                //Pass dummy ItemEntryRelation because, these are not used for In-Transit location
                UndoPostingMgt.PostItemJnlLineAppliedToList(
                    ItemJnlLine, TempApplyToEntryList, TransShptLine.Quantity, TransShptLine."Quantity (Base)", TempGlobalItemLedgEntry, TempDummyItemEntryRelation, false);

                // Then undo from-location item ledger entries
                TempApplyToEntryList.SetRange("Location Code", TransShptHeader."Transfer-from Code");
                TempApplyToEntryList.FindSet();
                UndoPostingMgt.PostItemJnlLineAppliedToList(
                    ItemJnlLine, TempApplyToEntryList, TransShptLine.Quantity, TransShptLine."Quantity (Base)", TempGlobalItemLedgEntry, TempGlobalItemEntryRelation, false);
            end;
        end;
        exit(0);
    end;

    local procedure MoveItemLedgerEntriesToTempRec(var ItemLedgerEntry: Record "Item Ledger Entry"; var TempItemLedgerEntry: Record "Item Ledger Entry" temporary)
    begin
        if ItemLedgerEntry.FindSet() then
            repeat
                TempItemLedgerEntry.TransferFields(ItemLedgerEntry);
                TempItemLedgerEntry.Insert();
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure PostCorrectiveItemLedgEntries(var ItemJnlLine: Record "Item Journal Line"; var ItemLedgEntry: Record "Item Ledger Entry")
    begin
        repeat
            ItemJnlLine."Applies-to Entry" := ItemLedgEntry."Entry No.";
            ItemJnlLine."Location Code" := ItemLedgEntry."Location Code";
            ItemJnlLine.Quantity := ItemLedgEntry.Quantity;
            ItemJnlLine."Quantity (Base)" := ItemLedgEntry.Quantity;
            ItemJnlLine."Invoiced Quantity" := ItemLedgEntry."Invoiced Quantity";
            ItemJnlLine."Invoiced Qty. (Base)" := ItemLedgEntry."Invoiced Quantity";
            //OnPostCorrectiveItemLedgEntriesOnBeforeRun(ItemJnlLine, ItemLedgEntry);
            ItemJnlPostLine.Run(ItemJnlLine);
        until ItemLedgEntry.Next() = 0;
    end;

    local procedure GetShptEntries(TransShptLine: Record "Transfer Shipment Line"; var ItemLedgEntry: Record "Item Ledger Entry"): Boolean
    begin
        ItemLedgEntry.SetCurrentKey("Document No.", "Document Type", "Document Line No.");
        ItemLedgEntry.SetRange("Document Type", ItemLedgEntry."Document Type"::"Transfer Shipment");
        ItemLedgEntry.SetRange("Document No.", TransShptLine."Document No.");
        ItemLedgEntry.SetRange("Document Line No.", TransShptLine."Line No.");
        exit(ItemLedgEntry.FindSet());
    end;

    local procedure CheckTransferShptLine(TransShptLine: Record "Transfer Shipment Line")
    var
        TempItemLedgEntry: Record "Item Ledger Entry" temporary;
    begin
        if TransShptLine."Correction Line" then
            Error(AlreadyReversedErr);

        UndoPostingMgt.TestTransferShptLine(TransShptLine);

        UndoPostingMgt.CollectItemLedgEntries(
            TempItemLedgEntry, Database::"Transfer Shipment Line", TransShptLine."Document No.", TransShptLine."Line No.", TransShptLine."Quantity (Base)", TransShptLine."Item Shpt. Entry No.");
        UndoPostingMgt.CheckItemLedgEntries(TempItemLedgEntry, TransShptLine."Line No.", false);
    end;

    local procedure UpdateDerivedTransferLine(var TransferLine: Record "Transfer Line"; var TransferShptLine: Record "Transfer Shipment Line")
    var
        DerivedTransferLine: Record "Transfer Line";
        TransferShipmentLine: Record "Transfer Shipment Line";
    begin
        // Find the derived line
        DerivedTransferLine.SetRange("Document No.", TransferShptLine."Transfer Order No.");
        DerivedTransferLine.SetRange("Line No.", TransferShptLine."Derived Trans. Order Line No.");
        DerivedTransferLine.FindFirst();
        DerivedTransferLine.TestField("Derived From Line No.", TransferLine."Line No.");

        // Move tracking information from the derived line to the original line
        TransferTracking(DerivedTransferLine, TransferLine, TransferShptLine);

        // Update any Transfer Shipment Lines that are pointing to this Derived Transfer Order Line
        TransferShipmentLine.SetRange("Transfer Order No.", DerivedTransferLine."Document No.");
        TransferShipmentLine.SetRange("Derived Trans. Order Line No.", DerivedTransferLine."Line No.");
        if TransferShipmentLine.FindSet() then
            TransferShipmentLine.ModifyAll("Derived Trans. Order Line No.", 0);

        // Reload the TransShptLine now that it has changed
        TransferShptLine.Get(TransferShptLine."Document No.", TransferShptLine."Line No.");

        // Delete the derived line - a new one gets created for each shipment
        DerivedTransferLine.Delete();
    end;

    local procedure TransferTracking(var FromTransLine: Record "Transfer Line"; var ToTransLine: Record "Transfer Line"; var TransferShptLine: Record "Transfer Shipment Line")
    var
        ReservationEntry: Record "Reservation Entry";
        ReserveTransLine: Codeunit "Transfer Line-Reserve";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        FromReservationEntryRowID: Text[250];
        ToReservationEntryRowID: Text[250];
        TransferQty: Decimal;
    begin
        TransferQty := FromTransLine.Quantity;
        ReserveTransLine.FindReservEntrySet(FromTransLine, ReservationEntry, "Transfer Direction"::Inbound);
        if ReservationEntry.IsEmpty() then
            exit;

        CheckReservationEntryStatus(ReservationEntry, TransferShptLine);

        FromReservationEntryRowID := ItemTrackingMgt.ComposeRowID( // From invisible TransferLine holding tracking
                    DATABASE::"Transfer Line", 1, ReservationEntry."Source ID", '', ReservationEntry."Source Prod. Order Line", ReservationEntry."Source Ref. No.");
        ToReservationEntryRowID := ItemTrackingMgt.ComposeRowID( // To original TransferLine
              DATABASE::"Transfer Line", 0, ReservationEntry."Source ID", '', 0, ReservationEntry."Source Prod. Order Line");

        ToTransLine.TestField("Variant Code", FromTransLine."Variant Code");

        // Recreate reservation entries on from-location which were deleted on posting shipment
        ItemTrackingMgt.CopyItemTracking(FromReservationEntryRowID, ToReservationEntryRowID, true); // Switch sign on quantities

        if not ReservationEntry.IsEmpty() then
            repeat
                ReservationEntry.TestItemFields(FromTransLine."Item No.", FromTransLine."Variant Code", FromTransLine."Transfer-to Code");
                UpdateTransferQuantity(TransferQty, ToTransLine, ReservationEntry);
            until (ReservationEntry.Next() = 0) or (TransferQty = 0);
    end;

    local procedure CheckReservationEntryStatus(var ReservationEntry: Record "Reservation Entry"; var TransferShipmentLine: Record "Transfer Shipment Line")
    begin
        ReservationEntry.SetFilter("Reservation Status", '<>%1', "Reservation Status"::Surplus);
        if ReservationEntry.FindFirst() then
            Error(NonSurplusResEntriesErr, TransferShipmentLine."Line No.", ReservationEntry."Entry No.");
        ReservationEntry.SetRange("Reservation Status");
        ReservationEntry.FindSet();
    end;

    local procedure UpdateTransferQuantity(var TransferQty: Decimal; var NewTransLine: Record "Transfer Line"; var OldReservEntry: Record "Reservation Entry")
    var
        CreateReservEntry: Codeunit "Create Reserv. Entry";
    begin
        TransferQty :=
            CreateReservEntry.TransferReservEntry(DATABASE::"Transfer Line",
            "Transfer Direction"::Inbound.AsInteger(), NewTransLine."Document No.", '', NewTransLine."Derived From Line No.",
            NewTransLine."Line No.", NewTransLine."Qty. per Unit of Measure", OldReservEntry, TransferQty);
    end;

    var
        NonSurplusResEntriesErr: Label 'You cannot undo transfer shipment line %1 because this line is Reserved. Reservation Entry No. %2', Comment = '%1 = Line No., %2 = Entry No.';
        GenJournalLine: Record "Gen. Journal Line";
        NotEnoughLineSpaceErr: Label 'There is not enough space to insert correction lines.';
        CheckingLinesMsg: Label 'Checking lines...';
        AlreadyReceivedErr: Label 'This shipment has already been received. Undo Shipment can only be applied to posted, but not received Transfer Lines.';
        NoDerivedTransOrderLineNoErr: Label 'The Transfer Shipment Line is missing a value in the field Derived Trans. Order Line No. This is automatically populated when posting new Transfer Shipments';
        NoTransOrderLineNoErr: Label 'The Transfer Shipment Line is missing a value in the field Trans. Order Line No. This is automatically populated when posting new Transfer Shipments';

        LocGSTRegNoARNNoErr: Label 'Location must have either GST Registration No. or Location ARN No.';
        TransferShipmentNoLbl: Label 'Transfer - %1', Comment = '%1= Transfer Shipment No.';

        TempGSTPostingBufferStage: Record "GST Posting Buffer" temporary;
        TempGSTPostingBufferFinal: Record "GST Posting Buffer" temporary;
        TempTransferBufferStage: Record "Transfer Buffer" temporary;
        TempTransferBufferFinal: Record "Transfer Buffer" temporary;
        GenJnlLine: Record "Gen. Journal Line";
        TempItemJnlLine: Record "Item Journal Line" temporary;
        // GSTTransferOrderShipment: Codeunit TransferShptGSTEntryCreateZero;
        GenJnlPostLine: Codeunit "Gen. Jnl.-Post Line";
#if not CLEAN22      
        //ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        ReserveTransLine: Codeunit "Transfer Line-Reserve";
#endif        
        GSTBaseValidation: Codeunit "GST Base Validation";
        CustomDutyAmount: Decimal;
        ItemJournalCustom: Decimal;
        RoundDiffAmt: Decimal;
        TransReceiptHeaderNo: Code[20];
        ItemLedgerEntryNo: Integer;
        LineNo: Integer;
        TotalQuantity: Decimal;
        FirstExecution: Boolean;
        GSTAmountLoaded: Decimal;
        TransferCost: Decimal;
        GSTAssessableErr: Label 'GST Assessable Value must be 0 if GST Group Type is Service while transferring from Bonded Warehouse location.';
        GSTCustomDutyErr: Label 'Custom Duty Amount must be 0 if GST Group Type is Service while transferring from Bonded Warehouse location.';
        GSTGroupServiceErr: Label 'You cannot select GST Group Type Service for transfer.';
        TransferReceiptNoLbl: Label 'Transfer - %1', Comment = '%1 = Transfer Receipt No.';


        myInt: Integer;
        RCHeadlinesPageCommon: Codeunit "RC Headlines Page Common";
        Text001: Label 'Cash transaction limit %1 is exceeding for the day ';
        Text002: Label 'Please approve the %1 and code as %2, currently it is in %3 Status';
        WorkflowManagement: Codeunit "Workflow Management";
        NoWorkflowEnabledErr: Label 'No approval workflow for this record type is enabled.';
        CanReOpenFinishedProdOrderQst: Label 'Do you want to reopen the production order %1 ?', Comment = '%1 - Production Order No.';
        OpenReleasedProdOrderQst: Label 'The production order is reopened and moved to the %1 Production Order with status Released.\\Do you want to open the production order?', Comment = '%1 = Production Order No.';
        ProductionOrderHasAlreadyBeenReopenedErr: Label 'This production order has already been reopened before. This can only be done once.';
        ProductionOrderCannotBeReopenedErr: Label 'This production order cannot be reopened because one or more production order lines have no posted output.';
        CompanyInfo: record "Company Information";
        EmailR: Codeunit System.Email.Email;
        SMTPMail: Codeunit "Email Message";
        UnixTimestampMgt: Codeunit "Unixtimestamp Transformation";
        ProdOrderCompSubst: Record "Prod. Order Component";
        ItemSubstitute: Codeunit "Item Subst.";
        TempItemSubstitution: Record "Item Substitution" temporary;
        Item: Record Item;
        ItemSubstitution: Record "Item Substitution";
        AvailToPromise: Codeunit "Available to Promise";
        GrossReq: Decimal;
        SchedRcpt: Decimal;
        ManufacturingDate: Date;
        Text007: Label 'There are multiple expiration dates registered for lot %1.';
        QtyToAssign: Decimal;
        UndoPurchreceiptLine: Codeunit "Undo Purchase Receipt Line";
        Text004: Label 'This receipt has already been invoiced. Undo Receipt can be applied only to posted, but not invoiced receipts.';

        TempWhseJnlLine: Record "Warehouse Journal Line" temporary;
        TempGlobalItemLedgEntry: Record "Item Ledger Entry" temporary;
        TempGlobalItemEntryRelation: Record "Item Entry Relation" temporary;
        UndoPostingMgt: Codeunit "Undo Posting Management";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        WhseUndoQty: Codeunit "Whse. Undo Quantity";

        PostandSend: Boolean;
        AllLinesCorrectedErr: Label 'All lines have been already corrected.';
        UndoSalesShipmentLine: Codeunit "Undo Sales Shipment Line";
        TempGlobalItemLedgerEntry: Record "Item Ledger Entry" temporary;
        TempGlobalItemEntryRelationSales: Record "Item Entry Relation" temporary;
        TempWarehouseJournalLine: Record "Warehouse Journal Line" temporary;
        AlreadyReversedErr: Label 'This shipment has already been reversed.';
        ItemJnlPostLine: Codeunit "Item Jnl.-Post Line";
        NextLineNo: Integer;
        UndoTransferShipmentCod: Codeunit "Undo Transfer Shipment";


}