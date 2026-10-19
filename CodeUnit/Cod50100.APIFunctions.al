codeunit 50100 "API Functions"
{
    Permissions = tabledata "Sales Invoice Header" = rm,
    tabledata "Sales Shipment Header" = rm,
    tabledata "Sales Shipment Line" = rim;

    var
        ScriptDatatypeMgmt: Codeunit "Script Data Type Mgmt.";
        ExcelBuffer: Record 370 temporary;
        TempBlob: Codeunit "Temp Blob";
        Location: Record 14;
        SalesHeader: Record 36;
        SalesLine: Record 37;
        PostedApprovalEntry: Record 454;
        SalespersonPurchaser: Record 13;
        OrderDate: Date;
        ReleasedOrderDate: DateTime;
        ShipToAdd: Text;
        SalesPersonName: Text;
        I: Integer;
        ReportName: array[10] of Text;

    [ServiceEnabled]
    procedure DayBook(ReportN: Text; GLAccount: Text; FromDate: Date; ToDate: Date; Branch: Text; ReportExt: Text): Text
    var
        GLEntry: Record "G/L Entry";
        RecGLAccount: Record "G/L Account";
        RecRef: RecordRef;
        Outstr: OutStream;
        Instr: InStream;
        Base64: Codeunit "Base64 Convert";
    Begin
        if ReportN = 'DayBook' then begin
            GLEntry.Reset();
            if GLAccount <> '' Then
                GLEntry.SetRange("G/L Account No.", GLAccount);
            GLEntry.SetRange("Posting Date", FromDate, ToDate);
            GLEntry.SetRange("Global Dimension 2 Code", Branch);
            if GLEntry.FindFirst() then begin
                RecRef.GetTable(GLEntry);
                TempBlob.CreateOutStream(Outstr);
                if ReportN = 'DayBook' Then Begin
                    if ReportExt = 'Pdf' then
                        Report.SaveAs(Report::"Day Book", '', ReportFormat::Pdf, Outstr, RecRef);
                    if ReportExt = 'Excel' then
                        Report.SaveAs(Report::"Day Book", '', ReportFormat::Excel, Outstr, RecRef);
                End;
            end;
        end;
        if ReportN = 'CashBook' Then Begin
            RecGLAccount.Reset();
            RecGLAccount.SetRange("No.", GLAccount);
            RecGLAccount.SetRange("Date Filter", FromDate, ToDate);
            RecGLAccount.SetRange("Global Dimension 2 Filter", Branch);
            if RecGLAccount.FindFirst() then begin
                RecRef.GetTable(RecGLAccount);
                TempBlob.CreateOutStream(Outstr);
                if ReportExt = 'Pdf' then
                    Report.SaveAs(Report::"Cash Book", '', ReportFormat::Pdf, Outstr, RecRef);
                if ReportExt = 'Excel' then
                    Report.SaveAs(Report::"Cash Book", '', ReportFormat::Excel, Outstr, RecRef);
            end;
        End;
        TempBlob.CreateInStream(Instr);
        Exit(Base64.ToBase64(Instr));
    End;

    [ServiceEnabled]
    procedure InventoryAgeing(Asondate: Date; ItemNo: Text; Period: Integer; ColumnLength: DateFormula; LocationFilter: Text): Text
    var
        Items: Record Item;
        InventoryAgeing: Report 50095;
        RecRef: RecordRef;
        Outstr: OutStream;
        Instr: InStream;
        Base64: Codeunit "Base64 Convert";
    Begin
        Items.Reset();
        if ItemNo <> '' Then
            Items.SetFilter("No.", ItemNo);
        Items.SetFilter("Location Filter", LocationFilter);
        if Items.FindFirst() Then begin
            RecRef.GetTable(Items);
            TempBlob.CreateOutStream(Outstr);
            //InventoryAgeing.Reportfilter(Asondate, Period, ColumnLength, LocationFilter);
            InventoryAgeing.SaveAs('', ReportFormat::Excel, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;

    End;

    [ServiceEnabled]
    procedure GetPstdDocLinesToReverse(SourceDocNo: Code[20]; CurrentMenuType: Integer; CopyDocNo: Code[20]; CopyDocLine: Integer): Text

    var
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        FromPurchRcptLine: Record "Purch. Rcpt. Line";
        FromPurchInvLine: Record "Purch. Inv. Line";
        FromPurchCrMemoLine: Record "Purch. Cr. Memo Line";
        FromReturnShptLine: Record "Return Shipment Line";
        ToPurchHeader: Record "Purchase Header";
        LinesNotCopied: Integer;
        MissingExCostRevLink: Boolean;
        Text000: Label 'The document lines that have a G/L account that does not allow direct posting have not been copied to the new document.';
    begin
        //OnBeforeCopyLineToDoc(CopyDocMgt, CurrentMenuType);
        ToPurchHeader.Reset();
        ToPurchHeader.SetRange("No.", SourceDocNo);
        if ToPurchHeader.FindFirst() then
            ToPurchHeader.TestField(Status, ToPurchHeader.Status::Open);
        //LinesNotCopied := 0;
        //OriginalQuantity := false;
        case CurrentMenuType of
            0:
                begin
                    FromReturnShptLine.Reset();
                    FromPurchRcptLine.SetRange("Document No.", CopyDocNo);
                    FromPurchRcptLine.SetRange("Line No.", CopyDocLine);
                    if FromPurchRcptLine.FindFirst() then;
                    //FromPurchRcptLine.Get(CopyDocNo, CopyDocLine);
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopyPurchaseLinesToDoc(
                      Enum::"Purchase Document Type From"::"Posted Receipt".AsInteger(), ToPurchHeader,
                      FromPurchRcptLine, FromPurchInvLine, FromReturnShptLine, FromPurchCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            1:
                begin
                    //CurrPage.PostedInvoices.PAGE.GetSelectedLine(FromPurchInvLine);
                    FromPurchInvLine.Reset();
                    FromPurchInvLine.SetRange("Document No.", CopyDocNo);
                    FromPurchInvLine.SetRange("Line No.", CopyDocLine);
                    if FromPurchInvLine.FindFirst() then;
                    //FromPurchInvLine.Get(CopyDocNo, CopyDocLine);
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopyPurchaseLinesToDoc(
                      Enum::"Purchase Document Type From"::"Posted Invoice".AsInteger(), ToPurchHeader,
                      FromPurchRcptLine, FromPurchInvLine, FromReturnShptLine, FromPurchCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            2:
                begin
                    //CurrPage.PostedReturnShpts.PAGE.GetSelectedLine(FromReturnShptLine);
                    FromReturnShptLine.Reset();
                    FromReturnShptLine.SetRange("Document No.", CopyDocNo);
                    FromReturnShptLine.SetRange("Line No.", CopyDocLine);
                    if FromReturnShptLine.FindFirst() then;
                    //FromReturnShptLine.Get(CopyDocNo, CopyDocLine);
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopyPurchaseLinesToDoc(
                      Enum::"Purchase Document Type From"::"Posted Return Shipment".AsInteger(), ToPurchHeader,
                      FromPurchRcptLine, FromPurchInvLine, FromReturnShptLine, FromPurchCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            3:
                begin
                    //CurrPage.PostedCrMemos.PAGE.GetSelectedLine(FromPurchCrMemoLine);
                    FromPurchCrMemoLine.Get(CopyDocNo, CopyDocLine);
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopyPurchaseLinesToDoc(
                      Enum::"Purchase Document Type From"::"Posted Credit Memo".AsInteger(), ToPurchHeader,
                      FromPurchRcptLine, FromPurchInvLine, FromReturnShptLine, FromPurchCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
        end;
        //CopyDocMgt.ShowMessageReapply(OriginalQuantity);
        Clear(CopyDocMgt);
        if LinesNotCopied <> 0 then
            Message(Text000);

        // OnAfterCopyLineToDoc(ToPurchHeader);

        //ShowLinesNotCopiedMessage();
    end;

    [ServiceEnabled]
    procedure GetPstdDocLinesToReverseSales(SourceDocNo: Code[20]; CurrentMenuType: Integer; CopyDocNo: Code[20]; CopyDocLine: Integer): Text

    var
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        FromSalesShptLine: Record "Sales Shipment Line";
        FromSalesInvLine: Record "Sales Invoice Line";
        FromSalesCrMemoLine: Record "Sales Cr.Memo Line";
        FromReturnRcptLine: Record "Return Receipt Line";
        ToSalesHeader: Record "Sales Header";
        IsHandled: Boolean;
        LinesNotCopied: Integer;
        MissingExCostRevLink: Boolean;
        Text000: Label 'The document lines that have a G/L account that does not allow direct posting have not been copied to the new document.';
    begin
        //OnBeforeCopyLineToDoc(CopyDocMgt, CurrentMenuType);
        ToSalesHeader.Reset();
        ToSalesHeader.SetRange("No.", SourceDocNo);
        if ToSalesHeader.FindFirst() then
            ToSalesHeader.TestField(Status, ToSalesHeader.Status::Open);
        LinesNotCopied := 0;

        case CurrentMenuType of
            0:
                begin
                    //CurrPage.PostedShpts.PAGE.GetSelectedLine(FromSalesShptLine);
                    FromSalesShptLine.Reset();
                    FromSalesShptLine.SetRange("Document No.", CopyDocNo);
                    FromSalesShptLine.SetRange("Line No.", CopyDocLine);
                    if FromSalesShptLine.FindFirst() then;
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopySalesLinesToDoc(
                      Enum::"Sales Document Type From"::"Posted Shipment".AsInteger(), ToSalesHeader,
                      FromSalesShptLine, FromSalesInvLine, FromReturnRcptLine, FromSalesCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            1:
                begin

                    //CurrPage.PostedInvoices.PAGE.GetSelectedLine(FromSalesInvLine);
                    FromSalesInvLine.Reset();
                    FromSalesInvLine.SetRange("Document No.", CopyDocNo);
                    FromSalesInvLine.SetRange("Line No.", CopyDocLine);
                    if FromSalesInvLine.FindFirst() then;
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopySalesLinesToDoc(
                      Enum::"Sales Document Type From"::"Posted Invoice".AsInteger(), ToSalesHeader,
                      FromSalesShptLine, FromSalesInvLine, FromReturnRcptLine, FromSalesCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            2:
                begin
                    // CurrPage.PostedReturnRcpts.PAGE.GetSelectedLine(FromReturnRcptLine);
                    FromReturnRcptLine.Reset();
                    FromReturnRcptLine.SetRange("Document No.", CopyDocNo);
                    FromReturnRcptLine.SetRange("Line No.", CopyDocLine);
                    if FromReturnRcptLine.FindFirst() then;
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopySalesLinesToDoc(
                      Enum::"Sales Document Type From"::"Posted Return Receipt".AsInteger(), ToSalesHeader,
                      FromSalesShptLine, FromSalesInvLine, FromReturnRcptLine, FromSalesCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
            3:
                begin
                    //CurrPage.PostedCrMemos.PAGE.GetSelectedLine(FromSalesCrMemoLine);
                    FromSalesCrMemoLine.Reset();
                    FromSalesCrMemoLine.SetRange("Document No.", CopyDocNo);
                    FromSalesCrMemoLine.SetRange("Line No.", CopyDocLine);
                    if FromSalesCrMemoLine.FindFirst() then;
                    CopyDocMgt.SetProperties(false, false, false, false, true, true, false);
                    CopyDocMgt.CopySalesLinesToDoc(
                      Enum::"Sales Document Type From"::"Posted Credit Memo".AsInteger(), ToSalesHeader,
                      FromSalesShptLine, FromSalesInvLine, FromReturnRcptLine, FromSalesCrMemoLine, LinesNotCopied, MissingExCostRevLink);
                end;
        end;
        Clear(CopyDocMgt);

        // IsHandled := false;
        // OnCopyLineToDocOnBeforeMessage(ToSalesHeader, IsHandled);
        // if not IsHandled then
        if LinesNotCopied <> 0 then
            Message(Text000);
    end;




    [ServiceEnabled]
    procedure PostGateEntry(DocNo: Code[20]; sFPL_User_ID: Text[50]): Text
    var
        GateEntryPost: Codeunit "Gate Entry Post";
        RecGateEntry: Record "Gate Entry Header";
    begin
        RecGateEntry.Reset();
        RecGateEntry.SetRange("No.", DocNo);
        if RecGateEntry.FindFirst() then
            GateEntryPost.Run(RecGateEntry);
        exit('Gate Entry has been Posted Sucussfully')
    end;

    [ServiceEnabled]
    procedure GetVoucher(DocNo: Code[20]; postingdate: Date): Text
    Var
        GLEntry: Record "G/L Entry";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        CurrentTime: DateTime;
    Begin
        GLEntry.Reset();
        GLEntry.SetRange("Document No.", DocNo);
        GLEntry.SetRange("Posting Date", postingdate);
        GLEntry.SetFilter("Source Code", '<>%1', 'INVTPCOST');
        If GLEntry.FindFirst() then begin
            RecRef.GetTable(GLEntry);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Posted Voucher1", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetWorkOrder(orderNo: Code[20]; puserID: text; PrintDateTime: Text): Text
    Var
        ProdOrder: Record "Production Order";
        WorkOrderReport: Report "Work Order SFPL";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        CurrentTime: DateTime;
    Begin
        ProdOrder.Reset();
        ProdOrder.SetRange("No.", orderNo);
        If ProdOrder.FindFirst() then begin
            RecRef.GetTable(ProdOrder);
            TempBlob.CreateOutStream(Outstr);
            CurrentTime := CurrentDateTime + (5 * 3600 + 30 * 60) * 1000;
            WorkOrderReport.GetDateTime(puserID, CurrentDateTime + (5 * 3600 + 30 * 60) * 1000);
            WorkOrderReport.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure PostedReport(DocumentType: Text; DocNo: Code[20]): Text
    Var
        PostedSalesCreditMemeo: Record "Sales Cr.Memo Header";
        PostedPurchCreditMemo: Record "Purch. Cr. Memo Hdr.";
        PostedPurchInvoice: Record "Purch. Inv. Header";
        PostedPurchreceipt: Record "Purch. Rcpt. Header";
        PostedReturnShipment: Record "Return Shipment Header";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        if DocumentType = 'SalesCreditMemo' Then begin
            PostedSalesCreditMemeo.Reset();
            PostedSalesCreditMemeo.SetRange("No.", DocNo);
            if PostedSalesCreditMemeo.FindFirst() then begin
                RecRef.GetTable(PostedSalesCreditMemeo);
                TempBlob.CreateOutStream(Outstr);
                Report.SaveAs(Report::"Credit Note", '', ReportFormat::Pdf, Outstr, RecRef);
                TempBlob.CreateInStream(Instr);
                Exit(Base64.ToBase64(Instr));
            end;
        end else
            if DocumentType = 'PurchCreditMemo' Then begin
                PostedPurchCreditMemo.Reset();
                PostedPurchCreditMemo.SetRange("No.", DocNo);
                if PostedPurchCreditMemo.FindFirst() then begin
                    RecRef.GetTable(PostedPurchCreditMemo);
                    TempBlob.CreateOutStream(Outstr);
                    Report.SaveAs(Report::"Debit Note", '', ReportFormat::Pdf, Outstr, RecRef);
                    TempBlob.CreateInStream(Instr);
                    Exit(Base64.ToBase64(Instr));
                end;
            end else
                if DocumentType = 'PurchReceipt' Then begin
                    PostedPurchreceipt.Reset();
                    PostedPurchreceipt.SetRange("No.", DocNo);
                    if PostedPurchreceipt.FindFirst() then begin
                        RecRef.GetTable(PostedPurchreceipt);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Purchase - Receipt1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        Exit(Base64.ToBase64(Instr));
                    end;
                end else
                    if DocumentType = 'PurchReturnShipment' Then begin
                        PostedReturnShipment.Reset();
                        PostedReturnShipment.SetRange("No.", DocNo);
                        if PostedReturnShipment.FindFirst() then begin
                            RecRef.GetTable(PostedReturnShipment);
                            TempBlob.CreateOutStream(Outstr);
                            Report.SaveAs(Report::"Purchase - Return Shipment", '', ReportFormat::Pdf, Outstr, RecRef);
                            TempBlob.CreateInStream(Instr);
                            Exit(Base64.ToBase64(Instr));
                        end;
                    end else
                        if DocumentType = 'PurchInvoice' Then begin
                            PostedPurchInvoice.Reset();
                            PostedPurchInvoice.SetRange("No.", DocNo);
                            if PostedPurchInvoice.FindFirst() then begin
                                RecRef.GetTable(PostedPurchInvoice);
                                TempBlob.CreateOutStream(Outstr);
                                Report.SaveAs(Report::"Purchase - Invoice", '', ReportFormat::Pdf, Outstr, RecRef);
                                TempBlob.CreateInStream(Instr);
                                Exit(Base64.ToBase64(Instr));
                            end;
                        end;
    End;

    [ServiceEnabled]
    procedure StockReport(StaringDate: Date; EndingDate: Date; itemNo: Text; loc: Code[20]; UserID: text): Text
    Var
        Items: Record Item;
        StockReport: Report "Stock Report";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        Items.Reset();
        If itemNo <> '' Then
            Items.Setfilter("No.", itemNo);
        if Items.FindFirst() then begin
            RecRef.GetTable(Items);
            TempBlob.CreateOutStream(Outstr);
            StockReport.Datefilter(StaringDate, EndingDate);
            StockReport.Locationfilter(loc, UserID);
            StockReport.SaveAs('', ReportFormat::Excel, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure SalesPLaning(locationCode: Code[20]): Text
    var
    //SalesPlanningExcel: Codeunit "Sales Planning Excel";
    begin
        GenerateReport(locationCode);
        exit(GetExcelBase64());
    end;

    procedure GenerateReport(LocationCodeFilter: Code[10])
    begin
        // Apply filters (based on report's RequestFilterFields)
        SalesHeader.Reset();
        SalesHeader.SetCurrentKey("Document Type", "Order Date", "Location Code");
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if LocationCodeFilter <> '' then
            SalesHeader.SetRange("Location Code", LocationCodeFilter);

        CreateHeader();

        if SalesHeader.FindSet() then
            repeat
                // Mimic Sales Header OnAfterGetRecord
                Clear(ReleasedOrderDate);
                PostedApprovalEntry.Reset();
                PostedApprovalEntry.SetRange("Document No.", SalesHeader."No.");
                PostedApprovalEntry.SetFilter(Status, 'Approved');
                if PostedApprovalEntry.FindFirst() then
                    ReleasedOrderDate := PostedApprovalEntry."Last Date-Time Modified";

                ShipToAdd := SalesHeader."Ship-to Address" + ' ' + SalesHeader."Ship-to Address 2";

                Clear(SalesPersonName);
                SalespersonPurchaser.Reset();
                SalespersonPurchaser.SetRange(Code, SalesHeader."Salesperson Code");
                if SalespersonPurchaser.FindFirst() then
                    SalesPersonName := SalespersonPurchaser.Name;

                // Process lines
                SalesLine.Reset();
                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                SalesLine.SetRange(Type, SalesLine.Type::Item);
                SalesLine.SetFilter("Responsibility Center", 'FEED|CATTLE|SWINE');
                if SalesLine.FindSet() then
                    repeat
                        // Mimic Sales Line OnAfterGetRecord
                        Clear(OrderDate);
                        Location.Reset();
                        if Location.Get(SalesLine."Location Code") then;
                        CreateBody();
                        OrderDate := SalesHeader."Order Date";
                    until SalesLine.Next() = 0;
            until SalesHeader.Next() = 0;

        // Mimic OnPostReport
        ExcelBuffer.CreateNewBook('Sales Planing');
        ExcelBuffer.WriteSheet('Sales Planing', CompanyName, UserId);
        ExcelBuffer.CloseBook();
        ExcelBuffer.SetFriendlyFilename(StrSubstNo('Sales Planing %1 %2', CurrentDateTime, UserId));
    end;

    procedure GetExcelBase64(): Text
    var
        Base64: Codeunit "Base64 Convert";
        InStr: InStream;
        OutStr: OutStream;
    begin
        TempBlob.CreateOutStream(OutStr);
        ExcelBuffer.SaveToStream(OutStr, true);
        TempBlob.CreateInStream(InStr);
        exit(Base64.ToBase64(InStr));
    end;

    local procedure CreateHeader()
    begin
        SetMatrixCaption();
        ExcelBuffer.NewRow();
        ExcelBuffer.AddColumn('Order Date', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Order No.', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('No.', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Description', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Quantity', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Outstanding Qty', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Total MRP Price', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Location Code', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Planned Delivery Date', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Planned Shipment', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Unit of Measurement', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Location State Code', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Customer Name', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Status', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Sell To City', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Ship To Name', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Ship To Add', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Ship To City', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Released Order Date', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Sales Person Name', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Transporter Code', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Freight', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Mode of Transport', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Vehicle No', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Driver Mob No', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('LR No', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('LR Date', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Vehicle Type (Ton)', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Freight Amount', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
    end;

    local procedure CreateBody()
    begin
        ExcelBuffer.NewRow();
        ExcelBuffer.AddColumn(SalesHeader."Order Date", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Date);
        ExcelBuffer.AddColumn(SalesHeader."No.", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn(SalesLine."No.", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn(SalesLine.Description, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesLine.Quantity, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn(SalesLine."Outstanding Quantity", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn(SalesLine."Total MRP Price", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn(SalesLine."Location Code", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesLine."Planned Delivery Date", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Date);
        ExcelBuffer.AddColumn(SalesLine."Planned Shipment Date", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Date);
        ExcelBuffer.AddColumn(SalesLine."Unit of Measure", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(Location."State Code", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesHeader."Sell-to Customer Name", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesHeader.Status, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesHeader."Sell-to City", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesHeader."Ship-to Name", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(ShipToAdd, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesHeader."Ship-to City", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(ReleasedOrderDate, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn(SalesPersonName, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('', false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
    end;

    local procedure SetMatrixCaption()
    begin
        ReportName[1] := 'Report Name :';
        ReportName[2] := 'Sales Planing';
        for I := 1 to 5 do begin
            if I = 2 then begin
                ReportName[1] := 'Report Filters :';
                ReportName[2] := SalesHeader.GetFilters();
            end else if I = 3 then begin
                ReportName[1] := 'WorkDate :';
                ReportName[2] := Format(Today);
            end else if I = 4 then begin
                ReportName[1] := 'USER :';
                ReportName[2] := UserId;
            end;

            if I <> 5 then begin
                ExcelBuffer.NewRow;
                ExcelBuffer.AddColumn(ReportName[1], FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(ReportName[2], FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
            END ELSE BEGIN
                ExcelBuffer.NewRow;
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ReportName[1] := '';
                ReportName[2] := '';
            END;
        end;
    end;


    [ServiceEnabled]
    procedure ConsumptionRepor(StaringDate: Date; EndingDate: Date; Loc: Text): Text
    Var
        ItemLedger: Record "Item Ledger Entry";
        ConsumptionReport: Report "Consumption Report";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        ItemLedger.Reset();
        ItemLedger.SetRange("Posting Date", StaringDate, EndingDate);
        ItemLedger.SetFilter("Location Code", '%1', Loc);
        if ItemLedger.FindFirst() then begin
            RecRef.GetTable(ItemLedger);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Consumption Report", '', ReportFormat::Excel, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    procedure GetDistance(FromPIN: Code[20]; ToPIN: Code[20]): Decimal
    var
        COde50061: Codeunit EwayBill;
    begin
        Exit(COde50061.CalculateDistance(FromPIN, ToPIN))
    end;


    [ServiceEnabled]
    procedure GetInvoiceReport(CustNo: Code[20]; FromDate: Date; ToDate: Date): Text
    var
        SalesInvoiceHeader1: Record "Sales Invoice Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        SalesInvoiceHeader1.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        SalesInvoiceHeader1.SetRange("Bill-to Customer No.", CustNo);
        SalesInvoiceHeader1.SetRange("Posting Date", FromDate, ToDate);
        SalesInvoiceHeader1.SetRange("Shortcut Dimension 1 Code", 'CATTLE');
        if SalesInvoiceHeader1.FindFirst() then begin
            RecRef.GetTable(SalesInvoiceHeader1);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Sales Invoice New-GST", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetTransferShipmentReport(ShipmentNo: Code[20]): Text
    var
        TransferShipment: Record "Transfer Shipment Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        TransferShipment.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        TransferShipment.SetRange("No.", ShipmentNo);
        if TransferShipment.FindFirst() then begin
            RecRef.GetTable(TransferShipment);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Transfer Order 2016", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetTransferReceiptReport(receiptNo: Code[20]): Text
    var
        TransferReceipt: Record "Transfer Receipt Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        TransferReceipt.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        TransferReceipt.SetRange("No.", receiptNo);
        if TransferReceipt.FindFirst() then begin
            RecRef.GetTable(TransferReceipt);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Transfer Receipt", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetPurchasereceiptReport(MRNNo: Code[20]): Text
    var
        Purchasereceipt: Record "Purch. Rcpt. Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        Purchasereceipt.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        Purchasereceipt.SetRange("No.", MRNNo);
        if Purchasereceipt.FindFirst() then begin
            RecRef.GetTable(Purchasereceipt);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Purchase - Receipt1", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetPurchaseOrderReport(OrderNo: Code[20]): Text
    var
        PurchaseOrder: Record "Purchase Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        PurchaseOrder.Reset();
        PurchaseOrder.SetRange("Document Type", Enum::"Purchase Document Type"::Order);
        PurchaseOrder.SetRange("No.", OrderNo);
        if PurchaseOrder.FindFirst() then begin
            RecRef.GetTable(PurchaseOrder);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Purchase Order1", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    Procedure UndoReceipt(DocNo: Code[20]; LineNo: Integer)
    var
        PurchRcptLine: Record "Purch. Rcpt. Line";
        COde50032: Codeunit BaseModificationCodeunitt;
    Begin
        PurchRcptLine.Reset();
        PurchRcptLine.SetRange("Document No.", DocNo);
        PurchRcptLine.SetRange("Line No.", LineNo);
        if PurchRcptLine.FindFirst() then
            COde50032.UndoReceipt(PurchRcptLine);
    End;

    [ServiceEnabled]
    procedure UndoReturnShipment(DOCNo: Code[20]; LineNo: Integer)
    var
        SalesShipmentLine: Record "Sales Shipment Line";
    Begin
        SalesShipmentLine.Reset();
        SalesShipmentLine.SetRange("Document No.", DOCNo);
        SalesShipmentLine.SetRange("Line No.", LineNo);
        if SalesShipmentLine.FindFirst() then
            COdeUnit50031.UndoShipment(SalesShipmentLine);
    End;

    [ServiceEnabled]
    procedure UndoShipment(DOCNo: Code[20]; LineNo: Integer)
    var
        SalesShipmentLine: Record "Sales Shipment Line";
    Begin
        SalesShipmentLine.Reset();
        SalesShipmentLine.SetRange("Document No.", DOCNo);
        SalesShipmentLine.SetRange("Line No.", LineNo);
        if SalesShipmentLine.FindFirst() then
            COdeUnit50031.UndoShipment(SalesShipmentLine);
    End;

    [ServiceEnabled]
    procedure UndoTransferShipment(DOCNo: Code[20]; LineNo: Integer)
    var
        TransferShipment: Record "Transfer Shipment Line";
    Begin
        TransferShipment.Reset();
        TransferShipment.SetRange("Document No.", DOCNo);
        TransferShipment.SetRange("Line No.", LineNo);
        if TransferShipment.FindFirst() then
            COdeUnit50031.UndoTransferShipment(TransferShipment);
    End;



    [ServiceEnabled]
    procedure GetInvoiceReportwithuseID(CustNo: Code[20]; FromDate: Date; ToDate: Date; UserID: Text; PrintdateTime: DateTime): Text
    var
        SalesInvoiceHeader1: Record "Sales Invoice Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        SalesInvoiceReport: Report "Sales Invoice New-GST";
    Begin
        SalesInvoiceHeader1.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        SalesInvoiceHeader1.SetRange("Bill-to Customer No.", CustNo);
        SalesInvoiceHeader1.SetRange("Posting Date", FromDate, ToDate);
        if SalesInvoiceHeader1.FindFirst() then begin
            RecRef.GetTable(SalesInvoiceHeader1);
            TempBlob.CreateOutStream(Outstr);
            SalesInvoiceReport.SetPrintIDandPrintTime(UserID, CurrentDateTime + (5 * 3600 + 30 * 60) * 1000);
            SalesInvoiceReport.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetCustStatementReportUserID(CustNo: Code[20]; FromDate: Date; ToDate: Date; UserID: Text; PrintdateTime: DateTime): Text
    var
        Cust: Record Customer;
        Rep50026: Report "Customer Statement_N";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;

    Begin
        Clear(Outstr);
        Cust.RESET;
        Cust.SETRANGE(Cust."No.", CustNo);
        // PDFVendor.SetRange("Date Filter", StartD, EndD);
        IF Cust.FINDFIRST THEN BEGIN
            RecRef.GetTable(Cust);
            TempBlob.CreateOutStream(Outstr);
            Rep50026.SetReportFilter(FromDate, ToDate);
            Rep50026.SetPrintIDandPrintTime(UserID, CurrentDateTime + (5 * 3600 + 30 * 60) * 1000);
            Rep50026.SetNarration(true);
            Rep50026.SavePDF(false);
            Rep50026.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);

            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetCustStatementReport(CustNo: Code[20]; FromDate: Date; ToDate: Date): Text
    var
        Cust: Record Customer;
        Rep50026: Report "Customer Statement_N";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;

    Begin
        Clear(Outstr);
        Cust.RESET;
        Cust.SETRANGE(Cust."No.", CustNo);
        // PDFVendor.SetRange("Date Filter", StartD, EndD);
        IF Cust.FINDFIRST THEN BEGIN
            RecRef.GetTable(Cust);
            TempBlob.CreateOutStream(Outstr);
            Rep50026.SetReportFilter(FromDate, ToDate);
            Rep50026.SetNarration(true);
            Rep50026.SavePDF(false);
            Rep50026.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);

            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetVendStatementReport(VendNo: Code[20]; FromDate: Date; ToDate: Date): Text
    var
        Vend: Record Vendor;
        Rep50015: Report "VLE Account Statement";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Outstr: OutStream;
        Instr: InStream;

    Begin
        Clear(Outstr);
        Vend.RESET;
        Vend.SETRANGE(Vend."No.", VendNo);
        // PDFVendor.SetRange("Date Filter", StartD, EndD);
        IF Vend.FINDFIRST THEN BEGIN
            RecRef.GetTable(Vend);
            TempBlob.CreateOutStream(Outstr);
            Rep50015.SetReportFilter(FromDate, ToDate);
            Rep50015.SavePDF(false);
            Rep50015.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure SalesOrderLine(
    "OrderNo": Code[20];
    "LineNo": Integer): Text

    var
        SaleLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        ApprovalsMgmt: Codeunit 1535;
        WorkflowWebhookManagement: Codeunit "Workflow Webhook Management";
        ReleasealesDocument: Codeunit "Release Sales Document";
    Begin
        SaleLine.Reset();
        SaleLine.SetRange("Document No.", OrderNo);
        SaleLine.SetRange("Line No.", "LineNo");
        if SaleLine.FindFirst() Then begin
            if SaleLine."Qty. Shipped (Base)" <> 0 then
                Error('Item Already Shipped, Can not Delete or Edit')
            else begin
                SalesHeader.Get(Enum::"Sales Document Type"::Order, OrderNo);
                if SalesHeader.Status = SalesHeader.Status::Released then
                    ReleasealesDocument.PerformManualReopen(SalesHeader);
                if SalesHeader.Status = SalesHeader.Status::"Pending Approval" then Begin
                    ApprovalsMgmt.OnCancelSalesApprovalRequest(SalesHeader);
                    WorkflowWebhookManagement.FindAndCancel(SalesHeader.RecordId);
                End;
                SaleLine.Delete(true);
                exit('Order and line has been deleted')
            end;

        End else
            Error('Order and Line does Not exist')


    end;

    [ServiceEnabled]
    procedure ReOpenSalesOrder(SalesOrderNo: Code[20]): Text
    var
        SalesHeader: Record "Sales Header";
        ReleaseSalesDocument: Codeunit "Release Sales Document";
        ApprovalsMgmt: Codeunit 1535;
        WorkflowWebhookMgt: Codeunit "Workflow Webhook Management";
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("No.", SalesOrderNo);
        if SalesHeader.FindFirst() then;
        //SalesHeader.Get(SalesHeader."Document Type"::Order, SalesOrderNo);
        if SalesHeader.Status = Enum::"Sales Document Status"::Released then
            ReleaseSalesDocument.PerformManualReopen(SalesHeader);

        if SalesHeader.Status = Enum::"Sales Document Status"::"Pending Approval" then begin
            ApprovalsMgmt.OnCancelSalesApprovalRequest(SalesHeader);
            WorkflowWebhookMgt.FindAndCancel(SalesHeader.RecordId);
        end;
        exit('Order Has been Opened');
    end;

    [ServiceEnabled]
    procedure CancelApprovalRequest(salesOrderNo: Code[20])
    var
        SalesHeader: Record "Sales Header";
        ApprovalsMgmt: Codeunit 1535;
        WorkflowWebhookMgt: Codeunit "Workflow Webhook Management";
    begin
        SalesHeader.Reset();
        SalesHeader.SetRange("No.", SalesOrderNo);
        if SalesHeader.FindFirst() then;
        //SalesHeader.Get(SalesHeader."Document Type"::Order, SalesOrderNo);
        if SalesHeader.Status = Enum::"Sales Document Status"::"Pending Approval" then begin
            ApprovalsMgmt.OnCancelSalesApprovalRequest(SalesHeader);
            WorkflowWebhookMgt.FindAndCancel(SalesHeader.RecordId);
        end;
    End;


    [ServiceEnabled]
    procedure SendApprovalRequest(SalesOrderNo: Code[20]): Text
    var
        C50006: Codeunit 50006;
        SalesLine_Rec: Record 37;
        SalesHeader_Rec: Record 36;
        TotalAmount_G: Decimal;
        TotalGatamt_G: Decimal;
        CreditLimitAmt: Decimal;
        Customer_A: Record 18;
        SalesLine: Record "Sales Line";
        TaxTransValue1: Record "Tax Transaction Value";
        SGST_perc1: Decimal;
        GSTSetup1: Record "GST Setup";
        TaxComponentName1: Text;
        CGST_perc1: Decimal;
        IGST_perc1: Decimal;
        TotalPer: Decimal;
        ApproovalAmt: Decimal;
        Customerrec: Record Customer;
        ApprovalsMgmt: Codeunit 1535;
        TemporaryCreditLimit: Record "Temporary Credit Limit";
        SalesHeader: Record "Sales Header";
        SalesHeader36: Record "Sales Header";
    begin

        SalesHeader.Reset();
        SalesHeader.SetRange("No.", SalesOrderNo);
        if SalesHeader.FindFirst() then begin
            if SalesHeader."Document Type" = Enum::"Sales Document Type"::Order Then begin
                SalesHeader.Get(Enum::"Sales Document Type"::Order, SalesOrderNo);
                SalesLine_Rec.RESET;
                SalesLine_Rec.SETRANGE("Document Type", SalesLine_Rec."Document Type"::Order);
                SalesLine_Rec.SETRANGE("Document No.", SalesOrderNo);
                //SalesLine_Rec.SETRANGE("Responsibility Center",'%1|%2','CATTLE|FEED');
                SalesLine_Rec.SETFILTER("No.", '<>%1', '');
                //SalesLine_Rec.SETFILTER("Unit Price",'<>%1',0);
                IF SalesLine_Rec.FINDSET THEN
                    REPEAT
                        IF ((SalesLine_Rec."No." = '') OR (SalesLine_Rec."Unit Price" = 0)) THEN
                            ERROR('Blank Line and Unit price should not blank or Zero if item no.entered');

                    UNTIL SalesLine_Rec.NEXT = 0;

                CLEAR(CreditLimitAmt);
                TemporaryCreditLimit.RESET;
                TemporaryCreditLimit.SETRANGE("Customer No", SalesHeader."Sell-to Customer No.");
                TemporaryCreditLimit.SETFILTER("Starting Date", '<=%1', SalesHeader."Order Date");
                TemporaryCreditLimit.SETFILTER("Ending Date", '%1|>=%2', 0D, SalesHeader."Order Date");
                IF TemporaryCreditLimit.FINDLAST THEN
                    CreditLimitAmt := TemporaryCreditLimit.Amount;

                //Gk19082021
                ApproovalAmt := 0;
                SalesHeader36.RESET;
                SalesHeader36.SETRANGE("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                SalesHeader36.SETRANGE("Document Type", SalesHeader36."Document Type"::Order);
                IF SalesHeader36.FINDSET THEN
                    REPEAT
                        SalesLine_Rec.RESET;
                        SalesLine_Rec.SETRANGE("Document No.", SalesHeader36."No.");
                        IF SalesLine_Rec.FINDFIRST THEN
                            REPEAT
                                IF ((SalesHeader36.Status = SalesHeader36.Status::Released) OR (SalesHeader36.Status = SalesHeader36.Status::"Pending Approval")) THEN Begin
                                    ApproovalAmt += SalesLine_Rec."Outstanding Amount";
                                    ApproovalAmt += SalesLine_Rec."Shipped Not Invoiced";
                                End;
                            UNTIL SalesLine_Rec.NEXT = 0;
                    UNTIL SalesHeader36.NEXT = 0;
                /////Pru_gk
                CLEAR(TotalAmount_G);
                SalesHeader_Rec.RESET;
                SalesHeader_Rec.SETFILTER(Status, '<>%1', SalesHeader_Rec.Status::"Short Closed");
                SalesHeader_Rec.SETRANGE("Document Type", SalesHeader_Rec."Document Type"::Order);
                SalesHeader_Rec.SETRANGE("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                SalesHeader_Rec.SETRANGE("No.", SalesHeader."No.");
                IF SalesHeader_Rec.FINDFIRST THEN
                    REPEAT
                        SalesLine_Rec.RESET;
                        SalesLine_Rec.SETRANGE("Document No.", SalesHeader_Rec."No.");
                        IF SalesLine_Rec.FINDFIRST THEN
                            REPEAT
                                clear(CGST_perc1);
                                Clear(SGST_perc1);
                                Clear(IGST_perc1);
                                GSTSetup1.Get();//PT
                                TaxTransValue1.Reset();

                                TaxTransValue1.SetRange("Tax Type", GSTSetup1."GST Tax Type");
                                TaxTransValue1.SetRange("Tax Record ID", SalesLine_Rec.RecordId());
                                TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
                                TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                                if TaxTransValue1.FindSet() then
                                    repeat
                                        TaxComponentName1 := TaxTransValue1.GetAttributeColumName();
                                        case TaxComponentName1 of
                                            'IGST':
                                                begin
                                                    IGST_perc1 := TaxTransValue1.Percent;

                                                end;
                                            'CGST':
                                                begin
                                                    CGST_perc1 := TaxTransValue1.Percent;
                                                end;
                                            'SGST':
                                                begin
                                                    CGST_perc1 := TaxTransValue1.Percent;
                                                end;
                                        end;
                                    until TaxTransValue1.Next() = 0;
                                TotalPer := CGST_perc1 + IGST_perc1 + SGST_perc1;
                                TotalGatamt_G := (((SalesLine_Rec."Outstanding Quantity" * SalesLine_Rec."Unit Price") - SalesLine_Rec."Line Discount Amount") * TotalPer / 100);
                                TotalAmount_G += (((SalesLine_Rec."Outstanding Quantity" * SalesLine_Rec."Unit Price") - SalesLine_Rec."Line Discount Amount") + TotalGatamt_G);
                            ////MESSAGE('%1',TotalAmount_G);
                            UNTIL SalesLine_Rec.NEXT = 0;
                    UNTIL SalesHeader_Rec.NEXT = 0;
                Customer_A.GET(SalesHeader."Sell-to Customer No.");
                Customer_A.CALCFIELDS("Balance (LCY)");
                IF Customer_A."Credit Limit (LCY)" <> 0 THEN BEGIN
                    IF (Customer_A."Credit Limit (LCY)" + CreditLimitAmt) - Customer_A."Balance (LCY)" < (TotalAmount_G + ApproovalAmt) THEN
                        ERROR('Remaining Credit Limit is insufficient to send the Approval for the Sale Order No. %1', SalesHeader."No." + '.');
                END;
                IF Customer_A."Credit Limit (LCY)" <> 0 THEN BEGIN
                    Customer_A.CALCFIELDS("Balance (LCY)");
                    IF (Customer_A."Credit Limit (LCY)" + CreditLimitAmt) - Customer_A."Balance (LCY)" <= 0 THEN
                        ERROR('Remaining Credit Limit is insufficient to send the Approval for the Sale Order No. %1', SalesHeader."No." + '.');
                END;
            end;

            // if (SalesHeader."Shortcut Dimension 1 Code" = 'CATTLE') then begin
            //     if (SalesHeader."Order Date" <= 20260325D) then begin
            if ApprovalsMgmt.CheckSalesApprovalPossible(SalesHeader) then
                ApprovalsMgmt.OnSendSalesDocForApproval(SalesHeader);
            //     End else
            //         Error('Cattle team Can not send order after 25th march, team leader will be confirm you to make order in system.');
            // End else begin
            //     if ApprovalsMgmt.CheckSalesApprovalPossible(SalesHeader) then
            //         ApprovalsMgmt.OnSendSalesDocForApproval(SalesHeader);
            // end;

            exit('Approval has been Sent to release Order');
        end;
    end;

    procedure UpdateOrderStatus(OrderNO: COde[20]; Status: Enum "Sales Document Status"): Text
    var
        gResponseMsg: Text;
        gRequestMsg: Text;
        gContent: HttpContent;
        gContentHeaders: HttpHeaders;
        gHttpClient: HttpClient;
        JobjectText: Text;
        gHttpResponseMsg: HttpResponseMessage;
        gHttpRequestMsg: HttpRequestMessage;
        URL: Text;
        Body2: Text;
        Json: Text;
        URL1: Text[200];
        jObject: JsonObject;
        Status1: Text;
        SalesHeader: Record "Sales Header";
        EnumStatus: Enum "Sales Document Status";
    begin

        Clear(jObject);



        SalesHeader.Get(SalesHeader."Document Type"::Order, OrderNO);
        // jObject.Add('orderNo', SalesHeader."No.");
        // jObject.Add('status', Status);
        // jObject.WriteTo(JobjectText);

        URL := 'http://103.10.191.226:8020/api/Order/Update-Order-Status?orderNo=' + OrderNO + '&status=' + Format(Status);
        ClearLastError();
        Clear(gResponseMsg);
        gContent.GetHeaders(gContentHeaders);
        gContent.WriteFrom(JobjectText);
        gContentHeaders.Remove('Content-Type');
        gContentHeaders.Add('Content-Type', 'application/json');
        gHttpClient.DefaultRequestHeaders.add('Authorization', 'Basic QWRtaW46QWRtaW5AMTIz');
        gHttpRequestMsg.SetRequestUri(URL);
        //gHttpRequestMsg.Content := gContent;
        gHttpRequestMsg.Method('PATCH');
        if gHttpClient.Send(gHttpRequestMsg, gHttpResponseMsg) then begin
            if gHttpResponseMsg.IsSuccessStatusCode then begin
                gHttpResponseMsg.Content.ReadAs(gResponseMsg);
                Message(gRequestMsg);
            end;
        end;
    end;


    [ServiceEnabled]
    procedure ForgetPasswordForWebUser(UserID: Text; RegistredModileNo: Text[10]): Text
    var
        WebUser: record WebUsers;
        PasswordHandler: Codeunit "Password Handler";
        Whatsapp: Codeunit "WhatsApp Function";
        SMSDetail: Codeunit "SMS Details";
    Begin
        WebUser.Reset();
        WebUser.SetRange(WebUser."User Name", UserID);
        WebUser.SetRange(WebUser."Modile No.", RegistredModileNo);
        if WebUser.FindFirst() then begin
            if WebUser.Status = WebUser.Status::Inactive then
                Error('User Account is Disabled');
            WebUser.Password := Format(Random(9999999));
            WebUser."Password Reset in Next Login" := True;
            WebUser.Modify();
            if SMSDetail.APISMSSingalNo(WebUser."Modile No.", 'Your Sampoorna Mobile App Password is ' + WebUser.Password + ' From: Sampoorna Feeds Pvt. Ltd.', '', WebUser."User Name", '1307174738068902039') Then
                //if Whatsapp.SendSMS(WebUser."Modile No.", 'Your Sampoorna Mobile App Password is ' + WebUser.Password + ' From: Sampoorna Feeds Pvt. Ltd.', '', WebUser."User Name", '1307174738068902039') Then
                exit('Password has been sent your registered mobile no.')
        end else begin
            WebUser.Reset();
            WebUser.SetRange(WebUser."User Name", UserID);
            if not WebUser.FindFirst() then
                Error('User ID not matched')
            else begin
                if WebUser."Modile No." <> RegistredModileNo then
                    Error('Registred Mobile No. not matched')

            end;
        end;

    End;

    [ServiceEnabled]
    procedure ResetPasswordWebuser(UserID: Text; OldPassword: Text[20]; NewPassword: Text[20]): Text
    var
        WebUser: Record WebUsers;
    Begin
        WebUser.Reset();
        WebUser.SetRange(WebUser."User Name", UserID);
        WebUser.SetRange(Password, OldPassword);
        if WebUser.FindFirst() then begin
            WebUser.Password := NewPassword;
            WebUser."Password Reset in Next Login" := False;
            WebUser.Modify();
            exit('Password has been Sucussfully reset')
        end else
            Error('Old Password is wrong')
    End;

    [ServiceEnabled]
    procedure SalesPersonLoginAppWebuser(UserID: Text; Password: Text[20]): Text
    var
        Webuser: Record WebUsers;
    Begin
        Webuser.Reset();
        Webuser.SetRange(Webuser."User Name", UserID);
        Webuser.SetRange(Password, Password);
        Webuser.SetRange("Sales Person", True);
        if Webuser.FindFirst() then begin
            if not Webuser."Password Reset in Next Login" Then begin
                if Webuser.Status = Webuser.Status::Inactive then
                    Error('Account is Disable')
                else
                    Exit('OK');
            end else
                exit('First Login')
        end else
            Error('User ID and Password is wrong Conatct with IT')
    End;

    [ServiceEnabled]
    procedure SalesTeamLoginAppWebuser(UserID: Text; Password: Text[20]): Text
    var
        Webuser: Record WebUsers;
    Begin
        Webuser.Reset();
        Webuser.SetRange(Webuser."User Name", UserID);
        Webuser.SetRange(Password, Password);
        Webuser.SetRange(Webuser."Sales Team", True);
        if Webuser.FindFirst() then begin
            if not Webuser."Password Reset in Next Login" Then begin
                if Webuser.Status = Webuser.Status::Inactive then
                    Error('Account is Disable')
                else
                    Exit('OK');
            end else
                exit('First Login')
        end else
            Error('User ID and Password is wrong Conatct with IT')
    End;

    [ServiceEnabled]
    procedure WebVesionLoginWebuser(UserID: Text; Password: Text[20]): Text
    var
        Webuser: Record WebUsers;
    Begin
        Webuser.Reset();
        Webuser.SetRange(Webuser."User Name", UserID);
        Webuser.SetRange(Password, Password);
        if Webuser.FindFirst() then begin
            if not Webuser."Password Reset in Next Login" Then begin
                if Webuser.Status = Webuser.Status::Inactive then
                    Error('Account is Disable')
                else
                    Exit('OK');
            end else
                exit('First Login')
        end else
            Error('User ID and Password is wrong Conatct with IT')
    End;

    [ServiceEnabled]
    procedure ResetPasswordCustomer(UserID: Text; OldPassword: Text[20]; NewPassword: Text[20]): Text
    var
        Customer: Record Customer;
    Begin
        Customer.Reset();
        Customer.SetRange("No.", UserID);
        Customer.SetRange(Password, OldPassword);
        if Customer.FindFirst() then begin
            Customer.Password := NewPassword;
            Customer."Password Reset in Next Login" := False;
            Customer.Modify();
            exit('Password has been Sucussfully reset')
        end else
            Error('Old Password is wrong')
    End;

    [ServiceEnabled]
    procedure ForgetPasswordCustomer(UserID: Text; RegistredModileNo: Text[10]): Text
    var
        Customer: record Customer;
        PasswordHandler: Codeunit "Password Handler";
        Whatsapp: Codeunit "WhatsApp Function";
        SMSDetail: Codeunit "SMS Details";
    Begin
        Customer.Reset();
        Customer.SetRange(Customer."No.", UserID);
        Customer.SetRange(Customer."Phone No.", RegistredModileNo);
        if Customer.FindFirst() then begin
            Customer.Password := Format(Random(9999999));
            Customer."Password Reset in Next Login" := True;
            Customer.Modify();
            if SMSDetail.APISMSSingalNo(Customer."Phone No.", 'Your Sampoorna Mobile App Password is ' + Customer.Password + ' From: Sampoorna Feeds Pvt. Ltd.', '', Customer."No.", '1307174738068902039') Then
                exit('Password has been sent your registered mobile no.')
        end else begin
            Customer.Reset();
            Customer.SetRange(Customer."No.", UserID);
            if not Customer.FindFirst() then
                Error('User ID not matched')
            else begin
                if Customer."Phone No." <> RegistredModileNo then
                    Error('Registred Mobile No. not matched')

            end;
        end;

    End;

    [ServiceEnabled]
    procedure LoginAppCustomer(UserID: Text; Password: Text[20]): Text
    var
        Customer: record Customer;
    Begin
        Customer.Reset();
        Customer.SetRange("No.", UserID);
        Customer.SetRange(Password, Password);
        if Customer.FindFirst() then begin
            if not Customer."Password Reset in Next Login" Then begin
                if Customer.Blocked = Customer.Blocked::All then
                    Error('Account is Disable')
                else
                    Exit('OK');
            end else
                exit('First Login')
        end else
            Error('User ID and Password is wrong Conatct with your Dedicated Sales Person')
    End;

    [ServiceEnabled]
    procedure QRcodeforInvoice(InveoiceNo: Text[20]): Text
    Var
        SalesInvoice: Record "Sales Invoice Header";
        recGST: Record "Detailed GST Ledger Entry";
        RecBank: record "Bank Account";
        Companyinfo: Record "Company Information";
        SalesRece: Record "Sales & Receivables Setup";
        Base64: Codeunit "Base64 Convert";
        JsonResponse: JsonObject;
        JsonArray: JsonArray;
        JsonItem: JsonObject;
        SupplierGSTIN: Text;
        SupplierName: text;
        InvoiceNo: Text;
        Invoicedate: Date;
        Itemname: text;
        Invoicevalue: Decimal;
        GSTValue: Text;
        SGST: Decimal;
        CGST: Decimal;
        IGST: Decimal;
        PayeeUPIID: text;
        PayeeAccountNo: text;
        PayeeAccountIFSC: Text;
        JSONText: text;
        InStr: InStream;
        OutStr: OutStream;
        TempBlob: Codeunit "Temp Blob";

    Begin
        Companyinfo.Get;
        SalesRece.Get;
        SalesInvoice.Reset();
        SalesInvoice.SetRange("No.", InveoiceNo);
        If SalesInvoice.FindFirst() then begin
            SalesInvoice.CalcFields(Amount);
            RecBank.get(SalesInvoice."Bank Account No.");
            SupplierGSTIN := SalesInvoice."Location GST Reg. No.";
            SupplierName := Companyinfo.Name;
            InveoiceNo := SalesInvoice."No.";
            Invoicedate := SalesInvoice."Posting Date";
            Itemname := '';
            recGST.Reset();
            recGST.SetRange("Document No.", InveoiceNo);
            If recGST.FindFirst() then
                repeat
                    if recGST."GST Component Code" = 'CGST' then
                        CGST += ABS(recGST."GST Amount");
                    if recGST."GST Component Code" = 'SGST' then
                        SGST += ABS(recGST."GST Amount");
                    if recGST."GST Component Code" = 'IGST' then
                        IGST += ABS(recGST."GST Amount");
                Until recGST.Next() = 0;
            Invoicevalue := SalesInvoice.Amount + CGST + SGST + IGST;
            if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then begin
                if SalesInvoice."Shortcut Dimension 1 Code" = 'FEED' Then begin
                    PayeeUPIID := 'SFFD01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFFD01' + SalesInvoice."Bill-to Customer No.";
                end;
                if SalesInvoice."Shortcut Dimension 1 Code" = 'BREEDER' Then begin
                    PayeeUPIID := 'SFBR01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFBR01' + SalesInvoice."Bill-to Customer No."
                end;
                if SalesInvoice."Shortcut Dimension 1 Code" = 'CBF' Then begin
                    PayeeUPIID := 'SFCB01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFCB01' + SalesInvoice."Bill-to Customer No."
                end;
                if SalesInvoice."Shortcut Dimension 1 Code" = 'CATTLE' Then begin
                    PayeeUPIID := 'SFCT01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFCT01' + SalesInvoice."Bill-to Customer No."
                end;
                if SalesInvoice."Shortcut Dimension 1 Code" = 'HATCH' Then begin
                    PayeeUPIID := 'SFHT01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFHT01' + SalesInvoice."Bill-to Customer No."
                end;
                if SalesInvoice."Shortcut Dimension 1 Code" = 'SWINE' Then begin
                    PayeeUPIID := 'SFSW01' + SalesInvoice."Bill-to Customer No." + '@hdfcbank';
                    PayeeAccountNo := 'SFSW01' + SalesInvoice."Bill-to Customer No."
                end;
                PayeeAccountIFSC := RecBank."IFSC Code";
                GSTValue := Format(CGST) + ' / ' + Format(SGST) + ' / ' + Format(IGST) + ' / ' + '0';
            end else begin
                PayeeUPIID := SalesRece."UPI ID";
                PayeeAccountNo := RecBank."Bank Account No.";
                PayeeAccountIFSC := RecBank."IFSC Code";
                GSTValue := Format(CGST) + ' / ' + Format(SGST) + ' / ' + Format(IGST) + ' / ' + '0';
            end;

        end;
        // Create JSON array
        JsonItem.Add('Supplier GSTIN', SupplierGSTIN);
        JsonItem.Add('Supplier name', SupplierName);
        JsonItem.Add('Invoice No.', InveoiceNo);
        JsonItem.Add('Invoice Date', Invoicedate);
        JsonItem.Add('Item Name', Itemname);
        JsonItem.Add('Invoice Value', Invoicevalue);
        JsonItem.Add('CGST /SGST /IGST /CESS', GSTValue);
        JsonItem.Add('Payee UPI ID', PayeeUPIID);
        JsonItem.Add('Payee Account No.', PayeeAccountNo);
        JsonItem.Add('Payee Account IFSC', PayeeAccountIFSC);

        if Companyinfo.Picture.HasValue then begin
            Companyinfo.CalcFields(Picture); // Ensure the BLOB field is loaded
            Companyinfo.Picture.CreateInStream(InStr);
            TempBlob.CreateOutStream(OutStr); // Create an OutStream
            CopyStream(OutStr, InStr); // Copy data from InStream to OutStream

            TempBlob.CreateInStream(InStr); // Refresh the stream
            JsonItem.Add('CompanyLogo', Base64.ToBase64(InStr));
            Message(Base64.ToBase64(InStr)); // Avoid double encoding

        end;
        JsonArray.Add(JsonItem);
        JsonResponse.Add('data', JsonArray);
        //JsonResponse.WriteTo(JSONText);
        exit(Base64.ToBase64(Format(JsonResponse)));
    end;

    procedure ModifyShiptoCOde(CustCode: Code[20]; Code: Code[10]; Name: Text[100]; Address: text[100]; Address2: Text[50];
    City: Text[30]; State: Code[10]; PostCode: Code[20]; PhoneNo: Text[30]): Boolean
    var
        ShiptoCode: Record "Ship-to Address";
    Begin
        ShiptoCode.Get(CustCode, Code);
        if ShiptoCode.Name <> Name then
            ShiptoCode.Name := Name;
        if ShiptoCode.Address <> Address then
            ShiptoCode.Address := Address;
        if ShiptoCode."Address 2" <> Address2 then
            ShiptoCode."Address 2" := Address2;
        if ShiptoCode.City <> City then
            ShiptoCode.City := City;
        if ShiptoCode.State <> State then
            ShiptoCode.State := State;
        if ShiptoCode."Post Code" <> PostCode then
            ShiptoCode."Post Code" := PostCode;
        if ShiptoCode."Phone No." <> PhoneNo then
            ShiptoCode."Phone No." := PhoneNo;
        ShiptoCode.Modify(true);
        exit
    End;

    procedure OTPVarification(DocumentNo: Code[20]; Otp: Integer; UserID: Text[10]): Text
    var
        SalesShipment: Record "Sales Shipment Header";
        CodOTP: Codeunit BaseModificationCodeunitt;
    begin
        salesshipment.Reset();
        salesshipment.SetRange("No.", DocumentNo);
        if salesshipment.FindFirst() then begin
            if (salesshipment."OTP Varified at" <> 0DT) and (salesshipment."OTP Varified by" <> '') then
                Error('It is already Varified the Delivery by %1 on %2', salesshipment."OTP Varified by", salesshipment."OTP Varified at");
            if SalesShipment.OTP = Otp Then begin
                SalesShipment."OTP Varified at" := CurrentDateTime;
                SalesShipment."OTP Varified" := true;
                SalesShipment."OTP Varified by" := UserID;
                SalesShipment.Modify();
                exit('OTP Sucussfully Varified')
            end else
                Error('Update the Correct OTP');
        end;

    end;


    procedure OTPResend(DocumentNo: Code[20]): Text
    var
        SalesShipment: Record "Sales Shipment Header";
        CodOTP: Codeunit BaseModificationCodeunitt;
    begin
        salesshipment.Reset();
        salesshipment.SetRange("No.", DocumentNo);
        if salesshipment.FindFirst() then begin
            CodOTP.ReSendOTP(salesshipment);
        end;

    end;

    procedure OrderShiptocodeModify(DocumentNo: Code[20]; Shiptocode: code[10]): Text
    var
        SalesHeader: Record "Sales Header";

    Begin
        SalesHeader.Get(SalesHeader."Document Type"::Order, DocumentNo);
        if SalesHeader.Status in [SalesHeader.Status::Open] Then
            if SalesHeader."Ship-to Code" <> Shiptocode then begin
                SalesHeader.Validate("Ship-to Code", Shiptocode);
                SalesHeader.Modify(True);
                Exit('New Ship to Code has been updated')
            end;

    End;

    procedure GeneratePaymentQRCOdeforCustomer(No: Code[10]): Text
    Var
        gResponseMsg: Text;
        gContentHeaders: HttpHeaders;
        gContent: HttpContent;
        gHttpClient: HttpClient;
        URL: Text[1024];
        gHttpResponseMsg: HttpResponseMessage;
        JsonObj: JsonObject;
        JsonText: Text;
        OutStream: OutStream;
        FileName: Text;
        TempBlob: Codeunit "Temp Blob";
        Cust: Record Customer;
        CompanyInfo: Record "Company Information";
        PayeeUPIID: Text;
        Json: text;
    Begin
        Cust.Get(No);


        if Companyinfo.SFPLCompany in [Companyinfo.SFPLCompany::Sampoorna] Then begin
            if Cust."Responsibility Center" = 'FEED' Then begin
                PayeeUPIID := 'SFFD01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = 'BREEDER' Then begin
                PayeeUPIID := 'SFBR01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = 'CBF' Then begin
                PayeeUPIID := 'SFCB01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = 'CATTLE' Then begin
                PayeeUPIID := 'SFCT01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = 'HATCH' Then begin
                PayeeUPIID := 'SFHT01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = 'SWINE' Then begin
                PayeeUPIID := 'SFSW01' + Cust."No." + '@hdfcbank';

            end;
            if Cust."Responsibility Center" = '' Then begin
                PayeeUPIID := 'SFFD01' + Cust."No." + '@hdfcbank';
            end;
        End;

        JsonObj.Add('upi_id', Format(PayeeUPIID));
        //JsonObj.Add('amount', 5677);
        JsonObj.Add('name', Format(Cust.Name));
        //JsonObj.Add('note', 'testing scanner');
        JsonObj.Add('label', true); // Note: use Boolean for true/false values
        JsonObj.WriteTo(JsonText);
        URL := 'https://erp.sampoornafeeds.in/qrcode/payment';
        Clear(gResponseMsg);
        gContent.WriteFrom(JsonText);
        gContent.GetHeaders(gContentHeaders);
        gContentHeaders.Clear();
        gContentHeaders.Add('Content-Type', 'application/json');
        if gHttpClient.Post(URL, gContent, gHttpResponseMsg) then begin
            gHttpResponseMsg.Content.ReadAs(Json);
            if gHttpResponseMsg.IsSuccessStatusCode then begin
                exit(GetResponsesValue(Json, '"qr_base64"', ':', 1));
            END;
        end;
    end;

    procedure GeneratePaymentQRCOdeforInvoice(No: Code[20]): Text
    Var
        gResponseMsg: Text;
        gContentHeaders: HttpHeaders;
        gContent: HttpContent;
        gHttpClient: HttpClient;
        URL: Text[1024];
        gHttpResponseMsg: HttpResponseMessage;
        JsonObj: JsonObject;
        JsonText: Text;
        OutStream: OutStream;
        FileName: Text;
        TempBlob: Codeunit "Temp Blob";
        SalesInvoice: Record "Sales Invoice Header";
        CompanyInfo: Record "Company Information";
        PayeeUPIID: Text;
        Json: text;
        Base64: Codeunit "Base64 Convert";

        InStream: InStream;

    Begin
        CompanyInfo.Get;
        SalesInvoice.Get(No);

        JsonObj.Add('company', Format(CompanyInfo.Name));
        JsonObj.Add('inveoiceNo', Format(SalesInvoice."No."));
        JsonObj.WriteTo(JsonText);
        URL := 'https://erp.sampoornafeeds.in/qrcode/invoice';
        Clear(gResponseMsg);
        gContent.WriteFrom(JsonText);
        gContent.GetHeaders(gContentHeaders);
        gContentHeaders.Clear();
        gContentHeaders.Add('Content-Type', 'application/json');
        if gHttpClient.Post(URL, gContent, gHttpResponseMsg) then begin
            gHttpResponseMsg.Content.ReadAs(Json);
            if gHttpResponseMsg.IsSuccessStatusCode then begin
                //Message(GetResponsesValue(Json, '"qr_base64"', ':', 1));
                TempBlob.CreateOutStream(OutStream);
                Base64.FromBase64(GetResponsesValue(Json, '"qr_base64"', ':', 1), OutStream);
                TempBlob.CreateInStream(InStream);
                SalesInvoice."Payment QR Code".CreateOutStream(OutStream);
                CopyStream(OutStream, InStream);
                SalesInvoice."Pay QR Created" := True;
                SalesInvoice.Modify();
                SalesInvoice.CalcFields("Payment QR Code");
            END;
        end;
    end;



    procedure GetResponsesValue(resp3: Text; Lstr: Text; Strng: Text; Cnt: Integer): Text
    var
        mstr: Text;
        IntPos: Integer;
        i: Integer;
        Resp1: Text;
    begin
        IF STRPOS(resp3, Lstr) = 0 THEN
            EXIT('');
        FOR i := 1 TO Cnt DO BEGIN
            IntPos := STRPOS(resp3, Lstr) + STRLEN(Lstr);
            Resp1 := DELSTR(resp3, 1, IntPos);
            resp3 := Resp1;
        END;
        IF Lstr <> 'error' THEN BEGIN
            IF STRPOS(Resp1, Strng) <> 0 THEN
                Resp1 := COPYSTR(Resp1, 1, STRPOS(Resp1, Strng) - 1)
            ELSE
                Resp1 := COPYSTR(Resp1, 1, STRLEN(Resp1) - 1);
            Resp1 := SELECTSTR(1, Resp1);
        END;
        //    // IF NOT (Lstr = 'StatusDate') THEN
        //         Resp1 := DELCHR(Resp1, '=', ' ');
        Resp1 := DELCHR(Resp1, '=', '"');
        //     Resp1 := DELCHR(Resp1, '<', ':');
        Resp1 := DELCHR(Resp1, '=', '}');
        EXIT(Resp1);
    END;

    [ServiceEnabled]
    procedure SalesPriceAPI(SalesType: Enum "Sales Price Type"; SalesCode: Code[20]; ItemNo: Code[20]; Location: Code[10]; Unitofmeasure: Code[10]; OrderDate: Date): Text
    var
        SalesPrice: Record "Sales Price";
        Jsonheader: JsonObject;
        Jsonobject: JsonObject;
        jsondata: Text;
    Begin
        Clear(jsondata);
        SalesPrice.Reset();
        SalesPrice.SetRange("Sales Type", SalesPrice."Sales Type"::"Customer Price Group");
        SalesPrice.SetRange("Sales Code", SalesCode);
        SalesPrice.SetRange("Item No.", ItemNo);
        SalesPrice.SetRange("Variant Code", Location);
        SalesPrice.SetRange("Unit of Measure Code", Unitofmeasure);
        SalesPrice.SETFILTER("Starting Date", '<=%1', OrderDate);
        SalesPrice.SETFILTER("Ending Date", '%1|>=%2', 0D, OrderDate);
        if SalesPrice.FindFirst() then begin
            Jsonheader.Add('Sales_Type', SalesPrice."Sales Type");
            Jsonheader.Add('Sales_Code', SalesPrice."Sales Code");
            Jsonheader.Add('Item_No', SalesPrice."Item No.");
            Jsonheader.Add('UOM', SalesPrice."Unit of Measure Code");
            Jsonheader.Add('Location', SalesPrice."Variant Code");
            Jsonheader.Add('Unit_Price', SalesPrice."Unit Price");
            Jsonheader.Add('MRP', SalesPrice."MRP PRICE");
        end;

        Jsonobject.Add('Response', Jsonheader);
        Jsonobject.WriteTo(jsondata);
        if jsondata <> '' Then
            exit(jsondata)
        else
            exit('Sales Price Not Found')

    End;


    [ServiceEnabled]
    procedure InitiateUploadFileGJ(RecNo: Code[50]; FileName: Text; FileEncodedTextDialog: Text)
    var
        DocumentAttachment: Record "Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        FromRecRef: RecordRef;
        FldRef: FieldRef;
        OutStr: OutStream;
        Base64Convert: Codeunit "Base64 Convert";
        InStr: InStream;

    begin

        FromRecRef.OPEN(81, false, CompanyName);
        FldRef := FromRecRef.FIELD(7);
        FldRef.SETRANGE(RecNo);
        FromRecRef.FIND('-');
        TempBlob.CreateOutStream(OutStr);
        Base64Convert.FromBase64(FileEncodedTextDialog, OutStr);
        TempBlob.CreateInStream(InStr);
        if FileName <> '' then
            DocumentAttachment.SaveAttachment(FromRecRef, FileName, TempBlob);
    end;

    [ServiceEnabled]
    procedure InitiateUploadFilePurchase(RecNo: Code[50]; FileName: Text; FileEncodedTextDialog: Text)
    var
        DocumentAttachment: Record "Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        FromRecRef: RecordRef;
        FldRef: FieldRef;
        OutStr: OutStream;
        Base64Convert: Codeunit "Base64 Convert";
        InStr: InStream;

    begin
        FromRecRef.OPEN(38, false, CompanyName);
        FldRef := FromRecRef.FIELD(3);
        FldRef.SETRANGE(RecNo);
        FromRecRef.FIND('-');
        TempBlob.CreateOutStream(OutStr);
        Base64Convert.FromBase64(FileEncodedTextDialog, OutStr);
        TempBlob.CreateInStream(InStr);
        if FileName <> '' then
            DocumentAttachment.SaveAttachment(FromRecRef, FileName, TempBlob);
    end;

    [ServiceEnabled]
    procedure InitiateDownloadFilePurchase(RecID: Integer; RecNo: Code[50]; FileExtension: text[30]): Text
    var
        DocumentAttachment: Record "Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        InStr: InStream;
        OutStr: OutStream;
        Base64Convert: Codeunit "Base64 Convert";
        EncodedText: Text;
    begin
        // Find attachment for Purchase Header (Table 38)
        DocumentAttachment.SetFilter("Table ID", '%1|%2|%3|%4', 38, 124, 122, 81); // Purchase Header
        DocumentAttachment.SetRange(ID, RecID);
        DocumentAttachment.SetRange("No.", RecNo);
        DocumentAttachment.SetRange("File Extension", FileExtension);

        if DocumentAttachment.FindFirst() then begin
            // Export attachment into TempBlob
            TempBlob.CreateOutStream(OutStr);
            DocumentAttachment.ExportToStream(OutStr);

            // Convert to Base64
            TempBlob.CreateInStream(InStr);
            EncodedText := Base64Convert.ToBase64(InStr);

            exit(EncodedText);
        end
    end;



    [ServiceEnabled]
    procedure PostVouchers(UserID: Code[10]): Text //; DocumentNo: Text; LineNo: Integer
    Var
        GenJnPosting: Codeunit "Gen. Jnl.-Post";
        GenJnLine: Record "Gen. Journal Line";
        genLedger: Record "G/L Entry";
        Pdate: date;
    begin
        GenJnLine.Reset();
        GenJnLine.SetFilter("Journal Template Name", '%1|%2|%3', 'GENERAL', 'CASH RECE', 'CASH PAYM');
        GenJnLine.SetFilter("Journal Batch Name", '%1', 'WEB');
        GenJnLine.SetRange("User ID", UserID);
        //GenJnLine.SetRange("Document No.", DocumentNo);
        //GenJnLine.SetRange("Line No.", LineNo);
        if GenJnLine.FindSet() then
            repeat
                Pdate := GenJnLine."Posting Date";
                GenJnPosting.Run(GenJnLine);
                genLedger.Reset();
                genLedger.SetCurrentKey("Entry No.");
                //genLedger.SetAscending("Entry No.", false);
                genLedger.SetRange("SFPL User ID", UserID);
                genLedger.SetRange("Posting Date", Pdate);
                if genLedger.FindLast() then
                    exit(genLedger."Document No.");
            Until GenJnLine.Next() = 0;
    end;


    [ServiceEnabled]
    procedure PostConsumeInventory(UserID: Code[10]): Text
    Var
        ItemJnPosting: Codeunit "Item Jnl.-Post Batch";
        ItemJnLine: Record "Item Journal Line";
    begin
        ItemJnLine.Reset();
        ItemJnLine.SetFilter("Journal Template Name", '%1', 'ITEM');
        ItemJnLine.SetFilter("Journal Batch Name", '%1', 'WEBAPP');
        ItemJnLine.SetRange(SFPLUserID, UserID);
        if ItemJnLine.FindFirst() then
            repeat
                ItemJnPosting.Run(ItemJnLine);

            Until ItemJnLine.Next() = 0;

        exit('Done');

    end;


    [ServiceEnabled]
    procedure CreateNoSeriesForVouchers(SeriesCode: Code[20]; PostingDate: Date) Result: Code[20]
    var
        NoSeriesMgmt: Codeunit NoSeriesManagement;
    begin
        Exit(NoSeriesMgmt.GetNextNo(SeriesCode, PostingDate, true));
    end;



    [ServiceEnabled]
    procedure GetTaxAttributesInJson(TableID: Integer; DocumentNo: text): Text
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        Datatype: Enum "Symbol Data Type";
        JArray: JsonArray;
        AttributeJObject: JsonObject;
        JObject: JsonObject;
        Base64: Codeunit "Base64 Convert";
        RecordRef: RecordRef;
        TaxRecordID: RecordId;
        GeneralJournal: Record "Gen. Journal Line";
        Purchaseline: record "Purchase Line";
        SalesLine: record "Sales Line";

    begin
        If TableID = 81 then begin
            GeneralJournal.Reset();
            GeneralJournal.SetRange("Document No.", DocumentNo);
            if GeneralJournal.FindFirst() then
                TaxRecordID := GeneralJournal.RecordId;

        end;


        TaxTransactionValue.SetFilter("Tax Record ID", '%1', TaxRecordID);
        TaxTransactionValue.SetFilter("Value Type", '<>%1', TaxTransactionValue."Value Type"::Component);
        TaxTransactionValue.SetRange("Visible on Interface", true);
        if TaxTransactionValue.FindSet() then
            repeat
                Clear(AttributeJObject);
                AttributeJObject.Add('AttributeName', TaxTransactionValue.GetAttributeColumName());
                Datatype := TaxTransactionValue.GetTransactionDataType();
                if TaxTransactionValue."Column Value" <> '' then
                    AttributeJObject.Add('Value', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(TaxTransactionValue."Column Value", Datatype))
                else
                    AttributeJObject.Add('Value', '');
                JArray.Add(AttributeJObject);
            until TaxTransactionValue.Next() = 0;



        exit(Base64.ToBase64(Format(JArray)));
    end;

    [ServiceEnabled]
    procedure GetTaxAttributesInJsonSales_Purchase(TableID: Integer; DocumentNo: text; LineNo: Integer): Text
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        Datatype: Enum "Symbol Data Type";
        JArray: JsonArray;
        AttributeJObject: JsonObject;
        JObject: JsonObject;
        Base64: Codeunit "Base64 Convert";
        RecordRef: RecordRef;
        TaxRecordID: RecordId;
        GeneralJournal: Record "Gen. Journal Line";
        Purchaseline: record "Purchase Line";
        SalesLine: record "Sales Line";

    begin

        if TableID = 39 then begin
            Purchaseline.Reset();
            Purchaseline.SetRange("Document No.", DocumentNo);
            Purchaseline.SetRange("Line No.", LineNo);
            if Purchaseline.FindFirst() then
                TaxRecordID := Purchaseline.RecordId;
        end;
        if TableID = 37 then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", DocumentNo);
            SalesLine.SetRange("Line No.", LineNo);
            if SalesLine.FindFirst() then
                TaxRecordID := SalesLine.RecordId;
        end;


        TaxTransactionValue.SetFilter("Tax Record ID", '%1', TaxRecordID);
        TaxTransactionValue.SetFilter("Value Type", '<>%1', TaxTransactionValue."Value Type"::Component);
        TaxTransactionValue.SetRange("Visible on Interface", true);
        if TaxTransactionValue.FindSet() then
            repeat
                Clear(AttributeJObject);
                AttributeJObject.Add('AttributeName', TaxTransactionValue.GetAttributeColumName());
                Datatype := TaxTransactionValue.GetTransactionDataType();
                if TaxTransactionValue."Column Value" <> '' then
                    AttributeJObject.Add('Value', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(TaxTransactionValue."Column Value", Datatype))
                else
                    AttributeJObject.Add('Value', '');
                JArray.Add(AttributeJObject);
            until TaxTransactionValue.Next() = 0;



        exit(Base64.ToBase64(Format(JArray)));
    end;


    [ServiceEnabled]
    procedure GetTaxComponentsInJson(TableID: Integer; DocumentNo: text): Text
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        TaxTypeObjHelper: Codeunit "Tax Type Object Helper";
        ComponentAmt: Decimal;
        JArray: JsonArray;
        ComponentJObject: JsonObject;
        JObject: JsonObject;
        Base64: Codeunit "Base64 Convert";
        RecordRef: RecordRef;
        TaxRecordID: RecordId;
        GeneralJournal: Record "Gen. Journal Line";

    begin
        GeneralJournal.Reset();
        GeneralJournal.SetRange("Document No.", DocumentNo);
        if GeneralJournal.FindFirst() then
            TaxRecordID := GeneralJournal.RecordId;



        TaxTransactionValue.SetFilter("Tax Record ID", '%1', TaxRecordID);
        TaxTransactionValue.SetFilter("Value Type", '%1', TaxTransactionValue."Value Type"::Component);
        TaxTransactionValue.SetRange("Visible on Interface", true);
        if TaxTransactionValue.FindSet() then
            repeat
                Clear(ComponentJObject);
                ComponentJObject.Add('Component', TaxTransactionValue.GetAttributeColumName());
                ComponentJObject.Add('Percent', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(format(TaxTransactionValue.Percent, 0, 9), "Symbol Data Type"::NUMBER));
                ComponentAmt := TaxTypeObjHelper.GetComponentAmountFrmTransValue(TaxTransactionValue);
                ComponentJObject.Add('Amount', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(format(ComponentAmt, 0, 9), "Symbol Data Type"::NUMBER));
                JArray.Add(ComponentJObject);
            until TaxTransactionValue.Next() = 0;
        //Message((Base64.ToBase64(Format(JObject.Add('TaxInformation', JArray)))));
        // Message(Format(JArray));
        exit(Base64.ToBase64(Format(JArray)));
    end;

    [ServiceEnabled]
    procedure GetTaxComponentsInJsonSales_Purchase(TableID: Integer; DocumentNo: text; LineNo: Integer): Text
    var
        TaxTransactionValue: Record "Tax Transaction Value";
        TaxTypeObjHelper: Codeunit "Tax Type Object Helper";
        ComponentAmt: Decimal;
        JArray: JsonArray;
        ComponentJObject: JsonObject;
        JObject: JsonObject;
        Base64: Codeunit "Base64 Convert";
        RecordRef: RecordRef;
        TaxRecordID: RecordId;
        Purchaseline: record "Purchase Line";
        SalesLine: record "Sales Line";

    begin

        if TableID = 39 then begin
            Purchaseline.Reset();
            Purchaseline.SetRange("Document No.", DocumentNo);
            Purchaseline.SetRange("Line No.", LineNo);
            if Purchaseline.FindFirst() then
                TaxRecordID := Purchaseline.RecordId;
        end;
        if TableID = 37 then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", DocumentNo);
            SalesLine.SetRange("Line No.", LineNo);
            if SalesLine.FindFirst() then
                TaxRecordID := SalesLine.RecordId;
        end;

        TaxTransactionValue.SetFilter("Tax Record ID", '%1', TaxRecordID);
        TaxTransactionValue.SetFilter("Value Type", '%1', TaxTransactionValue."Value Type"::Component);
        TaxTransactionValue.SetRange("Visible on Interface", true);
        if TaxTransactionValue.FindSet() then
            repeat
                Clear(ComponentJObject);
                ComponentJObject.Add('Component', TaxTransactionValue.GetAttributeColumName());
                ComponentJObject.Add('Percent', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(format(TaxTransactionValue.Percent, 0, 9), "Symbol Data Type"::NUMBER));
                ComponentAmt := TaxTypeObjHelper.GetComponentAmountFrmTransValue(TaxTransactionValue);
                ComponentJObject.Add('Amount', ScriptDatatypeMgmt.ConvertXmlToLocalFormat(format(ComponentAmt, 0, 9), "Symbol Data Type"::NUMBER));
                JArray.Add(ComponentJObject);
            until TaxTransactionValue.Next() = 0;
        //Message((Base64.ToBase64(Format(JObject.Add('TaxInformation', JArray)))));
        // Message(Format(JArray));
        exit(Base64.ToBase64(Format(JArray)));
    end;


    [ServiceEnabled]
    procedure RefressProductionOrder(ProdOrder: Code[20])
    var
        RefressProdReport: Report 99001025;
        ReleasedProdOrder: Record "Production Order";
    begin
        ReleasedProdOrder.Reset();
        ReleasedProdOrder.SetRange(Status, Enum::"Production Order Status"::Released);
        ReleasedProdOrder.SetRange("No.", ProdOrder);
        if ReleasedProdOrder.FindFirst() then
            Report.Run(99001025, false, false, ReleasedProdOrder);
    end;

    [ServiceEnabled]
    procedure ChangeProdOrderStatus(ProdOrder: Text; NewPostingDate: Date)
    var
        SuppressCommit: Boolean;
        IsHandled: Boolean;
        ReProdOrder: Record "Production Order";
        Status: Enum "Production Order Status";
        ProdOrderStatusManagement: Codeunit "Prod. Order Status Management";
        ReservMgt: Codeunit "Reservation Management";
    begin

        ReProdOrder.Reset();
        ReProdOrder.SetRange(Status, Enum::"Production Order Status"::Released);
        ReProdOrder.SetRange("No.", ProdOrder);
        if ReProdOrder.FindFirst() then
            ProdOrderStatusManagement.ChangeProdOrderStatus(ReProdOrder, Enum::"Production Order Status"::Finished, NewPostingDate, True);
    end;

    [ServiceEnabled]

    procedure TrackingAssign(ItemNo: Code[20]; LocationCode: Code[20]; Quantity: Decimal; QtytoHandle: Decimal; SourceProdOrderLine: Integer; SourceType: Integer; SourceSubType: Integer; SourceID: Code[20]; SourceBatch: Code[10]; SourcerefNo: Integer; LotNo: Code[50]; Expirationdate: Date; manufacuringdate: Date; NewExpirationdate: Date; NewManufacuringdate: Date; ReservationStatus: Integer): Text
    Var
        Reservation: Record "Reservation Entry";
    begin
        ;
        Reservation.Reset();
        Reservation.Init();
        Reservation.Validate("Item No.", ItemNo);
        Reservation."Reservation Status" := Enum::"Reservation Status".FromInteger(ReservationStatus);
        Reservation.Validate("Location Code", LocationCode);
        Reservation.Validate("Quantity (Base)", Quantity);
        Reservation.Validate("Qty. to Handle (Base)", QtytoHandle);
        Reservation.Validate("Source Type", SourceType);
        Reservation.Validate("Source Subtype", SourceSubType);
        Reservation.Validate("Source ID", SourceID);
        Reservation.Validate("Source Prod. Order Line", SourceProdOrderLine);
        Reservation.Validate("Source Batch Name", SourceBatch);
        Reservation.Validate("Source Ref. No.", SourcerefNo);
        Reservation.Validate("Lot No.", LotNo);
        Reservation."Expiration Date" := Expirationdate;
        Reservation."Manufacturing Date" := manufacuringdate;
        Reservation."New Expiration Date" := NewExpirationdate;
        Reservation."New Manufacturing Date" := NewManufacuringdate;
        Reservation."Item Tracking" := Enum::"Item Tracking Entry Type"::"Lot No.";
        if Quantity > 0 then
            Reservation.Positive := true;
        Reservation.Insert();
        exit('Tracking has been done');

    end;

    [ServiceEnabled]

    procedure QRCodePrint(ProdOrderNo: Code[20]): Text
    Var
        ReleProdOrder: Record "Production Order";

        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        ConvertFrom: Codeunit "Base64 Convert";
    begin
        ReleProdOrder.Reset();
        //ReleProdOrder.SetRange(Status, Enum::"Production Order Status"::Released);
        ReleProdOrder.SetRange("No.", ProdOrderNo);
        if ReleProdOrder.FindFirst() then begin
            RecRef.GetTable(ReleProdOrder);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Print Barcode", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    end;

    [ServiceEnabled]
    procedure GetCompSubst(ProdorderNo: Code[20]; ProdOrderLine: Integer; lineno: integer): Text
    var
        ConvertFrom: Codeunit "Base64 Convert";
        ItemSubst: codeunit "Item Subst.";
        ProdOrderCompSubst: Record "Prod. Order Component";
        ProdOrderComp: Record "Prod. Order Component";
        TempItemSubstitutionList: Record "Item Substitution" temporary;
        Jsonheader: JsonObject;
        SubstitutionObj: JsonObject;
        SubstitutionArray: JsonArray;
        jsondata: Text;
        Text000: Label 'This substitute item has a different sale unit of measure.';
        Text001: Label 'An Item Substitution with the specified variant does not exist for Item No. ''%1''.';
        Text002: Label 'An Item Substitution does not exist for Item No. ''%1''';

    begin
        Clear(jsondata);
        ProdOrderCompSubst.Get(Enum::"Production Order Status"::Released, ProdorderNo, ProdOrderLine, lineno);
        ProdOrderComp.Get(Enum::"Production Order Status"::Released, ProdorderNo, ProdOrderLine, lineno);

        if not PrepareSubstList(
             ProdOrderComp."Item No.",
             ProdOrderComp."Variant Code",
             ProdOrderComp."Location Code",
             ProdOrderComp."Due Date",
             true)
        then begin
            if ProdOrderComp."Variant Code" <> '' then
                Error(Text001, ProdOrderComp."Item No.");

            Error(Text002, ProdOrderComp."Item No.");
        end;
        //ItemSubst.ErrorMessage(ProdOrderComp."Item No.", ProdOrderComp."Variant Code");

        //OnGetCompSubstOnAfterCheckPrepareSubstList(ProdOrderComp, TempItemSubstitution, Item, GrossReq, SchedRcpt);

        TempItemSubstitution.Reset();
        TempItemSubstitution.SetRange("Variant Code", ProdOrderComp."Variant Code");
        TempItemSubstitution.SetRange("Location Filter", ProdOrderComp."Location Code");

        if TempItemSubstitution.FindSet() then begin
            // Create a JSON array to hold all substitutions
            //SubstitutionArray := JsonArray();

            repeat
                // Create a new JSON object for each record
                //SubstitutionObj := JsonObject();
                Clear(SubstitutionObj);
                SubstitutionObj.Add('Substitute_No.', TempItemSubstitution."Substitute No.");
                SubstitutionObj.Add('Description', TempItemSubstitution.Description);
                SubstitutionObj.Add('Inventory', TempItemSubstitution.Inventory);

                // Add the object to the array
                SubstitutionArray.Add(SubstitutionObj);
            until TempItemSubstitution.Next() = 0;

            // Finally, add the array to your header JSON
            JsonHeader.Add('Substitutions', SubstitutionArray);
        end;


        Jsonheader.WriteTo(jsondata);
        if jsondata <> '' Then
            exit(ConvertFrom.ToBase64(jsondata))
        else
            exit('Item Substitute Not Found')


    end;

    procedure PrepareSubstList(ItemNo: Code[20]; VariantCode: Code[10]; LocationCode: Code[10]; DemandDate: Date; CalcATP: Boolean): Boolean
    begin
        Item.Get(ItemNo);
        Item.SetFilter("Location Filter", LocationCode);
        Item.SetFilter("Variant Filter", VariantCode);
        Item.SetRange("Date Filter", 0D, DemandDate);

        ItemSubstitution.Reset();
        ItemSubstitution.SetRange(Type, ItemSubstitution.Type::Item);
        ItemSubstitution.SetRange("No.", ItemNo);
        ItemSubstitution.SetRange("Variant Code", VariantCode);
        ItemSubstitution.SetRange("Location Filter", LocationCode);
        if ItemSubstitution.Find('-') then begin
            TempItemSubstitution.DeleteAll();
            CreateSubstList(ItemNo, ItemSubstitution, 1, DemandDate, CalcATP);
            exit(true);
        end;

        exit(false);
    end;

    local procedure CreateSubstList(OrgNo: Code[20]; var ItemSubstitution3: Record "Item Substitution"; RelationsLevel: Integer; DemandDate: Date; CalcATP: Boolean)
    var
        ItemSubstitution: Record "Item Substitution";
        ItemSubstitution2: Record "Item Substitution";
        ODF: DateFormula;
        RelationsLevel2: Integer;
    begin
        ItemSubstitution.Copy(ItemSubstitution3);
        RelationsLevel2 := RelationsLevel;

        if ItemSubstitution.Find('-') then
            repeat
                Clear(TempItemSubstitution);
                TempItemSubstitution.Type := ItemSubstitution.Type;
                TempItemSubstitution."No." := ItemSubstitution."No.";
                TempItemSubstitution."Variant Code" := ItemSubstitution."Variant Code";
                TempItemSubstitution."Substitute Type" := ItemSubstitution."Substitute Type";
                TempItemSubstitution."Substitute No." := ItemSubstitution."Substitute No.";
                TempItemSubstitution."Substitute Variant Code" := ItemSubstitution."Substitute Variant Code";
                TempItemSubstitution.Description := ItemSubstitution.Description;
                TempItemSubstitution.Interchangeable := ItemSubstitution.Interchangeable;
                TempItemSubstitution."Location Filter" := ItemSubstitution."Location Filter";
                TempItemSubstitution."Relations Level" := RelationsLevel2;
                TempItemSubstitution."Shipment Date" := DemandDate;

                if CalcATP then begin
                    Item.Get(ItemSubstitution."Substitute No.");
                    //OnCreateSubstListOnBeforeCalcQtyAvail(Item, ProdOrderCompSubst, TempItemSubstitution);
                    // TempItemSubstitution."Quantity Avail. on Shpt. Date" :=
                    //   AvailToPromise.CalcQtyAvailabletoPromise(
                    //     Item, GrossReq, SchedRcpt,
                    //     Item.GetRangeMax("Date Filter"), "Analysis Period Type"::Month, ODF);
                    Item.CalcFields(Inventory);
                    //OnCreateSubstListOnAfterCalcQtyAvail(Item, ProdOrderCompSubst, TempItemSubstitution);
                    TempItemSubstitution.Inventory := Item.Inventory;
                end;

                if IsSubstitutionInserted(TempItemSubstitution, ItemSubstitution) then begin
                    ItemSubstitution2.SetRange(Type, ItemSubstitution.Type);
                    ItemSubstitution2.SetRange("No.", ItemSubstitution."Substitute No.");
                    ItemSubstitution2.SetFilter("Substitute No.", '<>%1&<>%2', ItemSubstitution."No.", OrgNo);
                    ItemSubstitution.CopyFilter("Variant Code", ItemSubstitution2."Variant Code");
                    ItemSubstitution.CopyFilter("Location Filter", ItemSubstitution2."Location Filter");
                    if ItemSubstitution2.FindFirst() then
                        CreateSubstList(OrgNo, ItemSubstitution2, RelationsLevel2 + 1, DemandDate, CalcATP);
                end else begin
                    TempItemSubstitution.Reset();
                    if TempItemSubstitution.Find() then
                        if RelationsLevel2 < TempItemSubstitution."Relations Level" then begin
                            TempItemSubstitution."Relations Level" := RelationsLevel2;
                            TempItemSubstitution.Modify();
                        end;
                end;
            until ItemSubstitution.Next() = 0;
    end;

    local procedure IsSubstitutionInserted(var ItemSubstitutionToCheck: Record "Item Substitution"; ItemSubstitution: Record "Item Substitution"): Boolean
    begin
        if ItemSubstitution."Substitute No." <> '' then
            with ItemSubstitutionToCheck do begin
                Reset();
                SetRange("Substitute Type", ItemSubstitution."Substitute Type");
                SetRange("Substitute No.", ItemSubstitution."Substitute No.");
                SetRange("Substitute Variant Code", ItemSubstitution."Substitute Variant Code");
                if IsEmpty() then
                    exit(Insert());
            end;
        exit(false);
    end;

    [ServiceEnabled]
    procedure CreateProductionJn(ProdOrderN: Code[20]; ActualLineNo: Integer; UserID: Text)
    var
        ProductionJnl: Page "Production Journal";
        ProgressBar: Dialog;
        LeaveForm: Boolean;
        IsHandled: Boolean;
        ProdOrder: Record "Production Order";

    begin
        ProdOrder.Get(Enum::"Production Order Status"::Released, ProdOrderN);
        MfgSetup.Get();

        SetTemplateAndBatchName(UserID);

        InitSetupValues();

        ProgressBar.Open(GeneratingJnlLinesMsg);
        DeleteJnlLines(ToTemplateName, ToBatchName, ProdOrder."No.", ActualLineNo);
        CreateJnlLines(ProdOrder, ActualLineNo);
        ProgressBar.Close();

        // IsHandled := false;
        // //OnBeforeRunProductionJnl(ToTemplateName, ToBatchName, ProdOrder, ActualLineNo, PostingDate, IsHandled);
        // if not IsHandled then begin
        //     repeat
        //         LeaveForm := true;
        //         Clear(ProductionJnl);
        //         ProductionJnl.Setup(ToTemplateName, ToBatchName, ProdOrder, ActualLineNo, PostingDate);
        //         ProductionJnl.RunModal();
        //         if DataHasChanged(ToTemplateName, ToBatchName, ProdOrder."No.", ActualLineNo) then
        //             LeaveForm := Confirm(Text001, true);
        //     until LeaveForm;

        // DeleteJnlLines(ToTemplateName, ToBatchName, ProdOrder."No.", ActualLineNo);
        // end;
    end;

    procedure CreateJnlLines(ProdOrder: Record "Production Order"; ProdOrderLineNo: Integer)
    var
        ItemJnlLine: Record "Item Journal Line";
        ProdOrderLine: Record "Prod. Order Line";
        ProdOrderRtngLine: Record "Prod. Order Routing Line";
        ProdOrderComp: Record "Prod. Order Component";
        IsHandled: Boolean;
    begin
        SetNextLineNo(ItemJnlLine);

        ProdOrderLine.Reset();
        ProdOrderLine.SetRange(Status, ProdOrder.Status);
        ProdOrderLine.SetRange("Prod. Order No.", ProdOrder."No.");
        if ProdOrderLineNo <> 0 then
            ProdOrderLine.SetRange("Line No.", ProdOrderLineNo);
        if ProdOrderLine.Find('-') then
            repeat
                ProdOrderRtngLine.Reset();
                ProdOrderRtngLine.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                ProdOrderRtngLine.SetRange("Routing No.", ProdOrderLine."Routing No.");
                ProdOrderRtngLine.SetRange(Status, ProdOrderLine.Status);
                ProdOrderRtngLine.SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
                if ProdOrderRtngLine.Find('-') then begin
                    InsertComponents(ProdOrderLine, true, 0); // With no Routing Link or illegal Routing Link
                    repeat

                        InsertOutputItemJnlLine(ProdOrderRtngLine, ProdOrderLine);
                        if ProdOrderRtngLine."Routing Link Code" <> '' then begin
                            ProdOrderComp.Reset();
                            ProdOrderComp.SetCurrentKey(Status, "Prod. Order No.", "Routing Link Code");
                            ProdOrderComp.SetRange(Status, ProdOrder.Status);
                            ProdOrderComp.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
                            ProdOrderComp.SetRange("Routing Link Code", ProdOrderRtngLine."Routing Link Code");
                            ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
                            ProdOrderComp.SetFilter("Item No.", '<>%1', '');
                            if ProdOrderComp.FindSet() then
                                repeat
                                    InsertConsumptionItemJnlLine(ProdOrderComp, ProdOrderLine, 1);
                                until ProdOrderComp.Next() = 0;

                        end;
                    until ProdOrderRtngLine.Next() = 0;
                end else begin
                    // Insert All Components - No Routing Link Check
                    InsertComponents(ProdOrderLine, false, 0);

                    // Create line for Output Qty
                    Clear(ProdOrderRtngLine);
                    InsertOutputItemJnlLine(ProdOrderRtngLine, ProdOrderLine);
                end;
            until ProdOrderLine.Next() = 0;

        Commit();
    end;

    procedure InsertOutputItemJnlLine(ProdOrderRtngLine: Record "Prod. Order Routing Line"; ProdOrderLine: Record "Prod. Order Line")
    var
        WorkCenter: Record "Work Center";
        MachineCenter: Record "Machine Center";
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        QtyToPost: Decimal;
        IsHandled: Boolean;
        ProdOrder: Record "Production Order";
    begin
        with ProdOrderLine do begin
            if ProdOrderRtngLine."Prod. Order No." <> '' then // Operation exist
                case ProdOrderRtngLine.Type of
                    ProdOrderRtngLine.Type::"Work Center":
                        begin
                            WorkCenter.Get(ProdOrderRtngLine."No.");
                            if WorkCenter.Blocked then begin
                                Message(Text005, WorkCenter.TableCaption(), WorkCenter."No.", ProdOrderRtngLine."Operation No.");
                                exit;
                            end;
                        end;
                    ProdOrderRtngLine.Type::"Machine Center":
                        begin
                            MachineCenter.Get(ProdOrderRtngLine."No.");
                            if MachineCenter.Blocked then begin
                                Message(Text005, MachineCenter.TableCaption(), MachineCenter."No.", ProdOrderRtngLine."Operation No.");
                                exit;
                            end;

                            WorkCenter.Get(ProdOrderRtngLine."Work Center No.");
                            if WorkCenter.Blocked then begin
                                Message(Text005, WorkCenter.TableCaption(), WorkCenter."No.", ProdOrderRtngLine."Operation No.");
                                exit;
                            end;
                        end;
                end;

            if (ProdOrderRtngLine."Flushing Method" <> ProdOrderRtngLine."Flushing Method"::Manual) or
               (PresetOutputQuantity = PresetOutputQuantity::"Zero on All Operations") or
               ((PresetOutputQuantity = PresetOutputQuantity::"Zero on Last Operation") and
                IsLastOperation(ProdOrderRtngLine)) or
               ((ProdOrderRtngLine."Prod. Order No." = '') and
                (PresetOutputQuantity <> PresetOutputQuantity::"Expected Quantity")) or
               (ProdOrderRtngLine."Routing Status" = ProdOrderRtngLine."Routing Status"::Finished)
            then
                QtyToPost := 0
            else
                if ProdOrderRtngLine."Prod. Order No." <> '' then
                    CalculateQtyToPostForProdOrder(ProdOrderLine, ProdOrderRtngLine, QtyToPost)
                else // No Routing Line
                    QtyToPost := "Remaining Quantity";

            if QtyToPost < 0 then
                QtyToPost := 0;

            ItemJnlLine.Init();
            //OnInsertOutputItemJnlLineOnAfterItemJnlLineInit(ItemJnlLine, ProdOrderLine, ItemJnlTemplate, ItemJnlBatch);
            ItemJnlLine."Journal Template Name" := ToTemplateName;
            ItemJnlLine."Journal Batch Name" := ToBatchName;
            ItemJnlLine."Line No." := NextLineNo;
            ItemJnlLine.Validate("Posting Date", PostingDate);
            ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Output);
            ItemJnlLine.Validate("Order Type", ItemJnlLine."Order Type"::Production);
            ItemJnlLine.Validate("Order No.", "Prod. Order No.");
            ItemJnlLine.Validate("Order Line No.", "Line No.");
            ItemJnlLine.Validate("Item No.", "Item No.");
            ItemJnlLine.Validate("Variant Code", "Variant Code");
            ItemJnlLine.Validate("Location Code", "Location Code");
            ItemJnlLine.Validate("Dimension Set ID", "Dimension Set ID");
            if "Bin Code" <> '' then
                ItemJnlLine.Validate("Bin Code", "Bin Code");
            ItemJnlLine.Validate("Routing No.", "Routing No.");
            ItemJnlLine.Validate("Routing Reference No.", "Routing Reference No.");
            if ProdOrderRtngLine."Prod. Order No." <> '' then
                ItemJnlLine.Validate("Operation No.", ProdOrderRtngLine."Operation No.");
            ItemJnlLine.Validate("Unit of Measure Code", "Unit of Measure Code");
            ItemJnlLine.Validate("Setup Time", 0);
            ItemJnlLine.Validate("Run Time", 0);
            //OnInsertOutputItemJnlLineOnAfterAssignTimes(ItemJnlLine, ProdOrderLine, ProdOrderRtngLine, QtyToPost);
            if ("Location Code" <> '') and IsLastOperation(ProdOrderRtngLine) then
                ItemJnlLine.CheckWhse("Location Code", QtyToPost);
            //OnInsertOutputItemJnlLineOnBeforeSubcontractingWorkCenterUsed(ItemJnlLine, ProdOrderLine);
            if ItemJnlLine.SubcontractingWorkCenterUsed() then
                ItemJnlLine.Validate("Output Quantity", 0)
            else begin
                if not IsLastOperation(ProdOrderRtngLine) then begin
                    ItemJnlLine."Qty. Rounding Precision" := 0;
                    ItemJnlLine."Qty. Rounding Precision (Base)" := 0;
                end;
                QtyToPost := UOMMgt.RoundQty(QtyToPost, ItemJnlLine."Qty. Rounding Precision (Base)");
                ItemJnlLine.Validate("Output Quantity", QtyToPost);
            end;


            if ProdOrderRtngLine."Routing Status" = ProdOrderRtngLine."Routing Status"::Finished then
                ItemJnlLine.Finished := true;
            ItemJnlLine."Flushing Method" := ProdOrderRtngLine."Flushing Method";
            ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
            ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
            ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
            ProdOrder.Get(Status, "Prod. Order No.");
            ItemJnlLine.SFPLUserID := ProdOrder."SFPL User ID";
            //OnBeforeInsertOutputJnlLine(ItemJnlLine, ProdOrderRtngLine, ProdOrderLine);
            ItemJnlLine.Insert();
            //OnAfterInsertOutputJnlLine(ItemJnlLine);

            if IsLastOperation(ProdOrderRtngLine) then
                ItemTrackingMgt.CopyItemTracking(RowID1(), ItemJnlLine.RowID1(), false);
            //OnInsertOutputItemJnlLineOnAfterCopyItemTracking(ItemJnlLine, ProdOrderRtngLine, NextLineNo);
        end;

        NextLineNo += 10000;

        RecursiveInsertOutputJnlLine(ProdOrderRtngLine, ProdOrderLine);
    end;

    local procedure RecursiveInsertOutputJnlLine(ProdOrderRoutingLine: Record "Prod. Order Routing Line"; ProdOrderLine: Record "Prod. Order Line")
    var
        AdditionalProdOrderLine: Record "Prod. Order Line";
        DoRecursion: Boolean;
    begin
        DoRecursion := false;
        //OnBeforeRecursiveInsertOutputJnlLine(ProdOrderRoutingLine, ProdOrderLine, DoRecursion, AdditionalProdOrderLine);
        if DoRecursion and AdditionalProdOrderLine.HasFilter then
            if AdditionalProdOrderLine.FindSet() then
                repeat
                    InsertOutputItemJnlLine(ProdOrderRoutingLine, AdditionalProdOrderLine);
                until AdditionalProdOrderLine.Next() = 0;
    end;

    local procedure CalculateQtyToPostForProdOrder(ProdOrderLine: Record "Prod. Order Line"; ProdOrderRoutingLine: Record "Prod. Order Routing Line"; var QtyToPost: Decimal)
    var
        CostCalcMgt: Codeunit "Cost Calculation Management";
    begin
        QtyToPost :=
            CostCalcMgt.CalcQtyAdjdForRoutingScrap(
                ProdOrderLine."Quantity (Base)",
                ProdOrderRoutingLine."Scrap Factor % (Accumulated)",
                ProdOrderRoutingLine."Fixed Scrap Qty. (Accum.)") -
            CostCalcMgt.CalcActOutputQtyBase(ProdOrderLine, ProdOrderRoutingLine);
        QtyToPost := QtyToPost / ProdOrderLine."Qty. per Unit of Measure";

    end;

    local procedure IsLastOperation(ProdOrderRoutingLine: Record "Prod. Order Routing Line") Result: Boolean
    begin
        Result := ProdOrderRoutingLine."Next Operation No." = '';

    end;


    procedure SetTemplateAndBatchName(UserID: Text)
    var
        PageTemplate: Option Item,Transfer,"Phys. Inventory",Revaluation,Consumption,Output,Capacity,"Prod. Order";
        User: Text;
        IsHandled: Boolean;
    begin
        ItemJnlTemplate.Reset();
        ItemJnlTemplate.SetRange("Page ID", PAGE::"Prod Jn");
        ItemJnlTemplate.SetRange(Recurring, false);
        ItemJnlTemplate.SetRange(Type, PageTemplate::"Prod. Order");
        if not ItemJnlTemplate.FindFirst() then begin
            ItemJnlTemplate.Init();
            ItemJnlTemplate.Recurring := false;
            ItemJnlTemplate.Validate(Type, PageTemplate::"Prod. Order");
            ItemJnlTemplate.Validate("Page ID");

            ItemJnlTemplate.Name := Format(ItemJnlTemplate.Type, MaxStrLen(ItemJnlTemplate.Name));
            ItemJnlTemplate.Description := StrSubstNo(Text000, ItemJnlTemplate.Type);
            ItemJnlTemplate.Insert();
        end;

        ToTemplateName := ItemJnlTemplate.Name;

        ToBatchName := '';
        User := UpperCase(UserID); // Uppercase in case of Windows Login


        if User <> '' then
            if (StrLen(User) < MaxStrLen(ItemJnlLine."Journal Batch Name")) and (ItemJnlLine."Journal Batch Name" <> '') then
                ToBatchName := CopyStr(ItemJnlLine."Journal Batch Name", 1, MaxStrLen(ItemJnlLine."Journal Batch Name") - 1) + 'A'
            else
                ToBatchName := DelChr(CopyStr(User, 1, MaxStrLen(ItemJnlLine."Journal Batch Name")), '>', '0123456789');

        if ToBatchName = '' then
            ToBatchName := Text003;

        if not ItemJnlBatch.Get(ToTemplateName, ToBatchName) then begin
            ItemJnlBatch.Init();
            ItemJnlBatch."Journal Template Name" := ItemJnlTemplate.Name;
            ItemJnlBatch.SetupNewBatch();
            ItemJnlBatch.Name := ToBatchName;
            ItemJnlBatch.Description := Text004;
            ItemJnlBatch.Insert(true);
        end;

        Commit();
    end;

    procedure InitSetupValues()
    begin
        MfgSetup.Get();
        PostingDate := WorkDate();
        CalcBasedOn := CalcBasedOn::"Expected Output";
        PresetOutputQuantity := MfgSetup."Preset Output Quantity";
    end;

    [ServiceEnabled]
    procedure DeleteProdJnlLines(ProdOrderNo: Code[20]; ProdOrderLineNo: Integer)
    var
        ItemJnlLine2: Record "Item Journal Line";
        ReservEntry: Record "Reservation Entry";
        IsHandled: Boolean;
    begin
        ItemJnlLine2.Reset();
        //ItemJnlLine2.SetRange("Journal Template Name", TemplateName);
        //ItemJnlLine2.SetRange("Journal Batch Name", BatchName);
        ItemJnlLine2.SetRange("Order Type", ItemJnlLine2."Order Type"::Production);
        ItemJnlLine2.SetRange("Order No.", ProdOrderNo);
        if ProdOrderLineNo <> 0 then
            ItemJnlLine2.SetRange("Order Line No.", ProdOrderLineNo);
        if ItemJnlLine2.Find('-') then begin
            repeat
                if ReservEntryExist(ItemJnlLine2, ReservEntry) then
                    ReservEntry.DeleteAll(true);
            until ItemJnlLine2.Next() = 0;


            ItemJnlLine2.DeleteAll(true);
        end;
    end;

    procedure ReservEntryExist(ItemJnlLine2: Record "Item Journal Line"; var ReservEntry: Record "Reservation Entry"): Boolean
    begin
        with ItemJnlLine2 do begin
            ReservEntry.Reset();
            ReservEntry.SetCurrentKey(
              "Source ID", "Source Ref. No.", "Source Type", "Source Subtype", "Source Batch Name", "Source Prod. Order Line");
            ReservEntry.SetRange("Source ID", "Journal Template Name");
            ReservEntry.SetRange("Source Ref. No.", "Line No.");
            ReservEntry.SetRange("Source Type", DATABASE::"Item Journal Line");
            ReservEntry.SetRange("Source Subtype", "Entry Type");
            ReservEntry.SetRange("Source Batch Name", "Journal Batch Name");
            ReservEntry.SetRange("Source Prod. Order Line", 0);
            if not ReservEntry.IsEmpty() then
                exit(true);

            exit(false);
        end;
    end;

    procedure SetNextLineNo(var ItemJournalLine: Record "Item Journal Line")
    begin
        ItemJournalLine.LockTable();
        ItemJournalLine.Reset();
        ItemJournalLine.SetRange("Journal Template Name", ToTemplateName);
        ItemJournalLine.SetRange("Journal Batch Name", ToBatchName);
        if ItemJournalLine.FindLast() then
            NextLineNo := ItemJournalLine."Line No." + 10000
        else
            NextLineNo := 10000;
    end;

    procedure InsertComponents(ProdOrderLine: Record "Prod. Order Line"; CheckRoutingLink: Boolean; Level: Integer)
    var
        ProdOrderComp: Record "Prod. Order Component";
        IsHandled: Boolean;
    begin

        // Components with no Routing Link or illegal Routing Link
        ProdOrderComp.Reset();
        ProdOrderComp.SetRange(Status, ProdOrderLine.Status);
        ProdOrderComp.SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
        ProdOrderComp.SetRange("Prod. Order Line No.", ProdOrderLine."Line No.");
        ProdOrderComp.SetFilter("Item No.", '<>%1', '');
        if ProdOrderComp.Find('-') then
            repeat
                if not CheckRoutingLink then
                    InsertConsumptionItemJnlLine(ProdOrderComp, ProdOrderLine, Level)
                else
                    if not RoutingLinkValid(ProdOrderComp, ProdOrderLine) then
                        InsertConsumptionItemJnlLine(ProdOrderComp, ProdOrderLine, Level);
            until ProdOrderComp.Next() = 0;
    end;

    procedure RoutingLinkValid(ProdOrderComp: Record "Prod. Order Component"; ProdOrderLine: Record "Prod. Order Line"): Boolean
    var
        ProdOrderRtngLine: Record "Prod. Order Routing Line";
        IsHandled: Boolean;
        Result: Boolean;
    begin

        if ProdOrderComp."Routing Link Code" = '' then
            exit(false);

        with ProdOrderRtngLine do begin
            Reset();
            SetRange(Status, ProdOrderLine.Status);
            SetRange("Prod. Order No.", ProdOrderLine."Prod. Order No.");
            SetRange("Routing Reference No.", ProdOrderLine."Routing Reference No.");
            SetRange("Routing No.", ProdOrderLine."Routing No.");
            SetRange("Routing Link Code", ProdOrderComp."Routing Link Code");
            exit(FindFirst());
        end;
    end;

    procedure InsertConsumptionItemJnlLine(ProdOrderComp: Record "Prod. Order Component"; ProdOrderLine: Record "Prod. Order Line"; Level: Integer)
    var
        Item: Record Item;
        ItemVariant: Record "Item Variant";
        Location: Record Location;
        ItemTrackingMgt: Codeunit "Item Tracking Management";
        NeededQty: Decimal;
        OriginalNeededQty: Decimal;
        IsHandled: Boolean;
        ShouldAdjustQty: Boolean;
        ItemItemVariantLbl: Label '%1 %2', Comment = '%1 - Item No., %2 - Variant Code';
        ProdOrder: Record "Production Order";
    begin
        with ProdOrderComp do begin
            Item.Get("Item No.");
            if Item.Blocked then begin
                Message(BlockedMsg, ProdOrderComp."Item No.", Item.TableCaption());
                exit;
            end;

            if ProdOrderComp."Variant Code" <> '' then begin
                ItemVariant.SetLoadFields(Blocked);
                ItemVariant.Get(ProdOrderComp."Item No.", ProdOrderComp."Variant Code");
                if ItemVariant.Blocked then begin
                    Message(BlockedMsg, StrSubstNo(ItemItemVariantLbl, ProdOrderComp."Item No.", ProdOrderComp."Variant Code"), ItemVariant.TableCaption());
                    exit;
                end;
            end;


            if "Flushing Method" <> "Flushing Method"::Manual then
                NeededQty := 0
            else
                NeededQty := GetNeededQty(CalcBasedOn, true);

            OriginalNeededQty := NeededQty;

            if "Flushing Method" = "Flushing Method"::Manual then begin
                if "Location Code" <> Location.Code then
                    if not Location.Get("Location Code") then
                        Clear(Location);

                if Location.Code = '' then
                    ShouldAdjustQty := Location."Require Shipment" and Location."Require Pick"
                else
                    ShouldAdjustQty := Location."Prod. Consump. Whse. Handling" = Location."Prod. Consump. Whse. Handling"::"Warehouse Pick (mandatory)";
                if ShouldAdjustQty then
                    AdjustQtyToQtyPicked(NeededQty);
            end;

            ItemJnlLine.Init();
            ItemJnlLine."Journal Template Name" := ToTemplateName;
            ItemJnlLine."Journal Batch Name" := ToBatchName;
            ItemJnlLine."Line No." := NextLineNo;
            ItemJnlLine.Validate("Posting Date", PostingDate);
            ItemJnlLine.Validate("Entry Type", ItemJnlLine."Entry Type"::Consumption);
            ItemJnlLine.Validate("Order Type", ItemJnlLine."Order Type"::Production);
            ItemJnlLine.Validate("Order No.", "Prod. Order No.");
            ItemJnlLine.Validate("Source No.", ProdOrderLine."Item No.");
            ItemJnlLine.Validate("Item No.", "Item No.");
            ItemJnlLine.Validate("Unit of Measure Code", "Unit of Measure Code");
            ItemJnlLine.Description := Description;
            ConsumptionItemJnlLineValidateQuantity(ProdOrderComp, NeededQty, Item, NeededQty < OriginalNeededQty);

            ItemJnlLine.Validate("Location Code", "Location Code");
            ItemJnlLine.Validate("Dimension Set ID", "Dimension Set ID");
            if "Bin Code" <> '' then
                ItemJnlLine."Bin Code" := "Bin Code";

            ItemJnlLine."Variant Code" := "Variant Code";
            ItemJnlLine.Validate("Order Line No.", "Prod. Order Line No.");
            ItemJnlLine.Validate("Prod. Order Comp. Line No.", "Line No.");

            ItemJnlLine.Level := Level;
            ItemJnlLine."Flushing Method" := "Flushing Method";
            ItemJnlLine."Source Code" := ItemJnlTemplate."Source Code";
            ItemJnlLine."Reason Code" := ItemJnlBatch."Reason Code";
            ItemJnlLine."Posting No. Series" := ItemJnlBatch."Posting No. Series";
            ProdOrder.Get(Status, "Prod. Order No.");
            ItemJnlLine.SFPLUserID := ProdOrder."SFPL User ID";


            ItemJnlLine.Insert();

            if Item."Item Tracking Code" <> '' then
                ItemTrackingMgt.CopyItemTracking(RowID1(), ItemJnlLine.RowID1(), false);
        end;

        NextLineNo += 10000;

    end;

    local procedure ConsumptionItemJnlLineValidateQuantity(ProdOrderComp: Record "Prod. Order Component"; NeededQty: Decimal; Item: Record Item; IgnoreRoundingPrecision: Boolean)
    var
        IsHandled: Boolean;
    begin

        if NeededQty <> 0 then
            if (Item."Rounding Precision" > 0) and not IgnoreRoundingPrecision then
                ItemJnlLine.Validate(Quantity, UOMMgt.RoundToItemRndPrecision(NeededQty, Item."Rounding Precision"))
            else
                ItemJnlLine.Validate(Quantity, Round(NeededQty, UOMMgt.QtyRndPrecision()));
    end;

    [ServiceEnabled]
    procedure PostRPO(RPONo: Code[20]; POstingdate: Date; SFPL_User_ID: Text[20]): Text
    Var
        ItemJnLine: Record "Item Journal Line";
        ItemJnLine2: Record "Item Journal Line";
        ItemJnLine3: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
    begin
        ItemJnLine2.Reset();
        ItemJnLine2.SetRange("Document No.", RPONo);
        if ItemJnLine2.FindFirst() then begin
            ItemJnLine2.ModifyAll("Posting Date", POstingdate);
            ItemJnLine2.ModifyAll(SFPLUserID, SFPL_User_ID);
        end;
        ItemJnLine3.Reset();
        ItemJnLine3.SetRange("Document No.", RPONo);
        ItemJnLine3.SetRange("Quantity (Base)", 0);
        if ItemJnLine3.FindFirst() then
            ItemJnLine3.DeleteAll();

        ItemJnLine.Reset();
        ItemJnLine.SetRange("Document No.", RPONo);
        if ItemJnLine.FindFirst() then begin
            CheckItemAvailability(ItemJnLine);
            ItemJnlPostBatch.Run(ItemJnLine);
            exit('Production Order has been Posted')
        end;
    end;



    local procedure CheckItemAvailability(var ItemJnlLine: Record "Item Journal Line")
    var
        Item: Record Item;
        TempSKU: Record "Stockkeeping Unit" temporary;
        ItemJnlLine2: Record "Item Journal Line";
        ConfirmManagement: Codeunit "Confirm Management";
        QtyinItemJnlLine: Decimal;
        AvailableQty: Decimal;
        IsHandled: Boolean;
    begin

        ItemJnlLine2.CopyFilters(ItemJnlLine);
        if ItemJnlLine2.FindSet() then
            repeat
                if ItemJnlLine2.IsNotInternalWhseMovement() then
                    if not TempSKU.Get(ItemJnlLine2."Location Code", ItemJnlLine2."Item No.", ItemJnlLine2."Variant Code") then
                        InsertTempSKU(TempSKU, ItemJnlLine2);
            //OnBeforeCheckItemAvailability(ItemJnlLine2, TempSKU);
            until ItemJnlLine2.Next() = 0;

        if TempSKU.FindSet() then
            repeat
                QtyinItemJnlLine := CalcRequiredQty(TempSKU, ItemJnlLine2);
                if QtyinItemJnlLine < 0 then begin
                    Item.Get(TempSKU."Item No.");
                    Item.SetFilter("Location Filter", TempSKU."Location Code");
                    Item.SetFilter("Variant Filter", TempSKU."Variant Code");
                    Item.SetRange("Date Filter", 0D, ItemJnlLine2."Posting Date");
                    Item.CalcFields("Reserved Qty. on Inventory", "Net Change");
                    AvailableQty := Item."Net Change"; //- Item."Reserved Qty. on Inventory" + SelfReservedQty(TempSKU, ItemJnlLine2);

                    //if (Item."Reserved Qty. on Inventory" > 0) and
                    if (AvailableQty < Abs(QtyinItemJnlLine)) then
                        Error('You have Insufficent Stock for Item No. %1', Item."No.");
                end;
            until TempSKU.Next() = 0;
    end;

    local procedure InsertTempSKU(var TempSKU: Record "Stockkeeping Unit" temporary; ItemJnlLine: Record "Item Journal Line")
    begin
        with TempSKU do begin
            if (ItemJnlLine."Entry Type" in
                [ItemJnlLine."Entry Type"::Sale,
                 ItemJnlLine."Entry Type"::"Negative Adjmt.",
                 ItemJnlLine."Entry Type"::Consumption]) or
               (ItemJnlLine."Entry Type" = ItemJnlLine."Entry Type"::Transfer)
            then begin
                Init();
                "Location Code" := ItemJnlLine."Location Code";
                "Item No." := ItemJnlLine."Item No.";
                "Variant Code" := ItemJnlLine."Variant Code";
                Insert();
            end;
        end;
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
        //ItemJnlLine.SetFilter(Quantity, '<%1', 0);
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


    [ServiceEnabled]
    procedure UpdateComponent(ProdOrderNo: Code[20]; ProdOrderLineNo: Integer; ComponenetLineNo: Integer; SubstItemNo: Code[20])
    var
        TempProdOrderComp: Record "Prod. Order Component" temporary;
        ProdOrderCompReserve: Codeunit "Prod. Order Comp.-Reserve";
        IsHandled: Boolean;
        ProdOrderComp: Record "Prod. Order Component";
        SubstVariantCode: Code[10];
        SaveQty: Decimal;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
    begin
        ProdOrderComp.Get(Enum::"Production Order Status"::Released, ProdOrderNo, ProdOrderLineNo, ComponenetLineNo);
        SubstVariantCode := '';
        if (ProdOrderComp."Item No." <> SubstItemNo) or (ProdOrderComp."Variant Code" <> SubstVariantCode) then
            ProdOrderCompReserve.DeleteLine(ProdOrderComp);

        TempProdOrderComp := ProdOrderComp;

        with TempProdOrderComp do begin
            SaveQty := "Quantity per";

            "Item No." := SubstItemNo;
            "Variant Code" := SubstVariantCode;
            "Location Code" := ProdOrderComp."Location Code";
            "Quantity per" := 0;
            Validate("Item No.");
            Validate("Variant Code");

            "Original Item No." := ProdOrderComp."Item No.";
            "Original Variant Code" := ProdOrderComp."Variant Code";

            if ProdOrderComp."Qty. per Unit of Measure" <> 1 then
                if ItemUnitOfMeasure.Get(Item."No.", ProdOrderComp."Unit of Measure Code") and
                   (ItemUnitOfMeasure."Qty. per Unit of Measure" = ProdOrderComp."Qty. per Unit of Measure")
                then
                    Validate("Unit of Measure Code", ProdOrderComp."Unit of Measure Code")
                else
                    SaveQty :=
                      Round(ProdOrderComp."Quantity per" * ProdOrderComp."Qty. per Unit of Measure", UOMMgt.QtyRndPrecision());
            Validate("Quantity per", SaveQty);
        end;


        ProdOrderComp := TempProdOrderComp;
        ProdOrderComp.Modify();
    end;

    procedure DeleteJnlLines(TemplateName: Code[10]; BatchName: Code[10]; ProdOrderNo: Code[20]; ProdOrderLineNo: Integer)
    var
        ItemJnlLine2: Record "Item Journal Line";
        ReservEntry: Record "Reservation Entry";
        IsHandled: Boolean;
    begin

        ItemJnlLine2.Reset();
        ItemJnlLine2.SetRange("Journal Template Name", TemplateName);
        ItemJnlLine2.SetRange("Journal Batch Name", BatchName);
        ItemJnlLine2.SetRange("Order Type", ItemJnlLine2."Order Type"::Production);
        ItemJnlLine2.SetRange("Order No.", ProdOrderNo);
        if ProdOrderLineNo <> 0 then
            ItemJnlLine2.SetRange("Order Line No.", ProdOrderLineNo);
        if ItemJnlLine2.Find('-') then begin
            repeat
                if ReservEntryExist(ItemJnlLine2, ReservEntry) then
                    ReservEntry.DeleteAll(true);
            until ItemJnlLine2.Next() = 0;

            ItemJnlLine2.DeleteAll(true);
        end;
    end;

    [ServiceEnabled]
    Procedure PostSales(DocNo: Code[20]; DefaultOption: Integer; sFPL_User_ID: text[20]): Text
    var
        SalesHeader: Record "Sales Header";
        SalesHeaderToPost: Record "Sales Header";
        recSalesHeader: Record "Sales Header";
        SalesLine_Rec: Record "Sales Line";
        Selection: Integer;
        ShipInvoiceOptionsQst: Label '&Ship,&Invoice,Ship &and Invoice';
        ReceiveInvoiceOptionsQst: Label '&Receive,&Invoice,Receive &and Invoice';
        SalesPost: Codeunit "Sales-Post";
        SalesLine: record "Sales Line";
        RecItem: Record "Item Ledger Entry";
        SalesInvoiceReport: Report "Sales Invoice New-GST";
        SalesShipmentReport: Report "Sales Delivery Note";
        RecSalesInvoice: Record "Sales Invoice Header";
        RecSalesInvoice1: Record "Sales Invoice Header";
        RecSalesShipment: record "Sales Shipment Header";
        RecSalesShipment1: record "Sales Shipment Header";
        RecSalesCreditMemo: Record "Sales Cr.Memo Header";
        RecSalesCreditMemo1: Record "Sales Cr.Memo Header";
        UserSetupManagement: Codeunit "User Setup Management";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        Base64: Codeunit "Base64 Convert";
        InvoiceBase64: Text;
        ShipmentBase64: Text;
        JObj: JsonObject;
        OrderNo: Code[20];
        Postingdate: Date;
        VehicleNo: text;
        AvailableStock: Decimal;
        SalesShipmentDOC: text;
        SalesInvoiceDOC: text;
        CustomerNo: text;

    begin
        Clear(OrderNo);
        Clear(Postingdate);
        Clear(VehicleNo);
        Clear(SalesInvoiceDOC);
        Clear(SalesShipmentDOC);
        Clear(CustomerNo);
        if DefaultOption > 3 then
            DefaultOption := 3;
        if DefaultOption <= 0 then
            DefaultOption := 1;
        recSalesHeader.Reset();
        recSalesHeader.SetRange("Document Type", Enum::"Sales Document Type"::Order);
        recSalesHeader.SetRange("No.", DocNo);
        If recSalesHeader.FindFirst() then begin
            recSalesHeader.TestField("Vehicle No.");
            SalesLine_Rec.RESET;
            SalesLine_Rec.SETRANGE("Document Type", recSalesHeader."Document Type");
            SalesLine_Rec.SETRANGE("Document No.", recSalesHeader."No.");
            SalesLine_Rec.SETFILTER("No.", '<>%1', '');
            IF SalesLine_Rec.FINDSET THEN
                REPEAT
                    IF (SalesLine_Rec."Unit Price" = 0) THEN
                        ERROR('Unit price should not blank or Zero of %1', SalesLine_Rec."No.");

                UNTIL SalesLine_Rec.NEXT = 0;
            recSalesHeader.TestField("External Document No.");
            recSalesHeader.UpdateSalesPrice(recSalesHeader."No.", recSalesHeader."Customer Price Group");
        end;

        SalesHeaderToPost.reset;
        SalesHeaderToPost.SetRange("No.", DocNo);
        if SalesHeaderToPost.FindFirst() then begin
            if DefaultOption in [2, 3] then
                varifyGST(SalesHeaderToPost."No.");
            SalesLine.Reset();
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", DocNo);
            SalesLine.SetRange(Type, Enum::"Sales Line Type"::Item);
            SalesLine.SetFilter("No.", '<>%1', '');
            SalesLine.SETFILTER("Qty. to Ship", '<>%1', 0);
            if SalesLine.FindFirst() then
                repeat
                    if DefaultOption in [1, 3] then begin
                        RecItem.Reset();
                        RecItem.SetRange("Item No.", SalesLine."No.");
                        RecItem.SetRange("Location Code", SalesLine."Location Code");
                        RecItem.SetRange("Posting Date", 0D, SalesHeaderToPost."Posting Date");
                        RecItem.SetFilter("Remaining Quantity", '<>%1', 0);
                        if RecItem.FindSet() then begin
                            RecItem.CalcSums("Remaining Quantity");
                            if (RecItem."Remaining Quantity" < SalesLine."Qty. to Ship (Base)") then
                                Error('You have Insufficent Stock for Item No. %1, Available Stock is %2, Required Stock is %3', RecItem."Item No.", RecItem."Remaining Quantity", SalesLine."Qty. to Ship (Base)");
                        end else begin
                            Error('You have Insufficent Stock for Item No. %1, Available Stock is %2, Required Stock is %3', RecItem."Item No.", RecItem."Remaining Quantity", SalesLine."Qty. to Ship (Base)");
                        end;
                    end;
                Until SalesLine.Next() = 0;
        end;
        SalesHeaderToPost.reset;
        SalesHeaderToPost.SetRange("No.", DocNo);
        if SalesHeaderToPost.FindFirst() then;
        SalesHeader.Copy(SalesHeaderToPost);
        case SalesHeader."Document Type" of
            SalesHeader."Document Type"::Order:
                begin
                    UpdateShipandInvoice(SalesHeader.Ship, SalesHeader.Invoice);
                    case true of
                        //UserSetupManagement.GetSalesInvoicePostingPolicy(SalesHeader.Ship, SalesHeader.Invoice);
                        not SalesHeader.Ship and not SalesHeader.Invoice:
                            begin
                                SalesHeader."SFPL User ID" := sFPL_User_ID;
                                SalesHeader.Ship := DefaultOption in [1, 3];
                                SalesHeader.Invoice := DefaultOption in [2, 3];
                            end;
                    end;
                end;
            SalesHeader."Document Type"::"Return Order":
                begin
                    UpdateShipandInvoice(SalesHeader.Ship, SalesHeader.Invoice);
                    case true of
                        not SalesHeader.Receive and not SalesHeader.Invoice:
                            begin
                                //Selection := StrMenu(ReceiveInvoiceOptionsQst, DefaultOption);
                                // if Selection = 0 then
                                //     exit(false);
                                SalesHeader."SFPL User ID" := sFPL_User_ID;
                                SalesHeader.Receive := DefaultOption in [1, 3];
                                SalesHeader.Invoice := DefaultOption in [2, 3];
                            end;
                    end;
                end;
            SalesHeader."Document Type"::Invoice, SalesHeader."Document Type"::"Credit Memo":
                begin
                    SalesHeader."SFPL User ID" := sFPL_User_ID;
                    UpdateShipandInvoice(SalesHeader.Ship, SalesHeader.Invoice);
                end;
            else
        end;
        OrderNo := SalesHeader."No.";
        Postingdate := SalesHeader."Posting Date";
        VehicleNo := SalesHeader."Vehicle No.";
        SalesHeaderToPost.Copy(SalesHeader);
        SalesPost.SetSuppressCommit(false);
        SalesPost.Run(SalesHeader);
        if SalesHeader."Document Type" in [SalesHeader."Document Type"::Order, SalesHeader."Document Type"::Invoice] then begin
            if DefaultOption in [3] then begin
                RecSalesInvoice.Reset();
                RecSalesInvoice.SetCurrentKey("No.", "Posting Date");
                RecSalesInvoice.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                RecSalesInvoice.SetRange("Order No.", DocNo);
                RecSalesInvoice.SetRange("Posting Date", Postingdate);
                RecSalesInvoice.SetRange("Vehicle No.", VehicleNo);
                If RecSalesInvoice.FindLast() Then Begin
                    RecSalesInvoice1.Reset();
                    RecSalesInvoice1.SetRange("No.", RecSalesInvoice."No.");
                    if RecSalesInvoice1.FindFirst() then begin
                        SalesInvoiceDOC := RecSalesInvoice1."No.";
                        CustomerNo := RecSalesInvoice1."Sell-to Customer No.";
                        RecRef.GetTable(RecSalesInvoice1);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Sales Invoice New-GST", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
                RecSalesShipment.Reset();
                RecSalesShipment.SetCurrentKey("No.", "Posting Date");
                RecSalesShipment.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                RecSalesShipment.SetRange("Order No.", DocNo);
                RecSalesShipment.SetRange("Posting Date", Postingdate);
                RecSalesShipment.SetRange("Vehicle No.", VehicleNo);
                If RecSalesShipment.FindLast() Then begin
                    RecSalesShipment1.Reset();
                    RecSalesShipment1.SetRange("No.", RecSalesShipment."No.");
                    if RecSalesShipment1.FindFirst() then begin
                        SalesShipmentDOC := RecSalesShipment1."No.";
                        CustomerNo := RecSalesShipment1."Sell-to Customer No.";
                        RecRef.GetTable(RecSalesShipment1);
                        Clear(Outstr);
                        Clear(Instr);
                        Clear(TempBlob);
                        Clear(Base64);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Sales Delivery Note", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [2] then begin
                RecSalesInvoice.Reset();
                RecSalesInvoice.SetRange("Order No.", DocNo);
                RecSalesInvoice.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                RecSalesInvoice.SetRange("Posting Date", Postingdate);
                RecSalesInvoice.SetRange("Vehicle No.", VehicleNo);
                If RecSalesInvoice.FindLast() Then Begin
                    RecSalesInvoice1.Reset();
                    RecSalesInvoice1.SetRange("No.", RecSalesInvoice."No.");
                    if RecSalesInvoice1.FindFirst() then begin
                        SalesInvoiceDOC := RecSalesInvoice1."No.";
                        CustomerNo := RecSalesInvoice1."Sell-to Customer No.";
                        RecRef.GetTable(RecSalesInvoice1);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Sales Invoice New-GST", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [1] then begin
                RecSalesShipment.Reset();
                RecSalesShipment.SetRange("Order No.", DocNo);
                RecSalesShipment.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                RecSalesShipment.SetRange("Posting Date", Postingdate);
                RecSalesShipment.SetRange("Vehicle No.", VehicleNo);
                If RecSalesShipment.FindLast() Then begin
                    RecSalesShipment1.Reset();
                    RecSalesShipment1.SetRange("No.", RecSalesShipment."No.");
                    if RecSalesShipment1.FindFirst() then begin
                        SalesShipmentDOC := RecSalesShipment1."No.";
                        CustomerNo := RecSalesShipment1."Sell-to Customer No.";
                        RecRef.GetTable(RecSalesShipment1);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Sales Delivery Note", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;
                end;

            end;
        end;
        if SalesHeader."Document Type" in [SalesHeader."Document Type"::"Return Order", SalesHeader."Document Type"::"Credit Memo"] then begin
            if DefaultOption in [3, 2] then begin
                RecSalesCreditMemo.Reset();
                RecSalesCreditMemo.SetCurrentKey("No.", "Posting Date");
                RecSalesCreditMemo.SetRange("Sell-to Customer No.", SalesHeader."Sell-to Customer No.");
                if SalesHeader."Document Type" in [SalesHeader."Document Type"::"Return Order"] then
                    RecSalesCreditMemo.SetRange("Return Order No.", SalesHeader."No.")
                Else
                    RecSalesCreditMemo.SetRange("Pre-Assigned No.", SalesHeader."No.");
                RecSalesCreditMemo.SetRange("Posting Date", Postingdate);
                RecSalesCreditMemo.SetRange("Vehicle No.", VehicleNo);
                If RecSalesCreditMemo.FindLast() Then Begin
                    RecSalesCreditMemo1.Reset();
                    RecSalesCreditMemo1.SetRange("No.", RecSalesCreditMemo."No.");
                    if RecSalesCreditMemo1.FindFirst() then begin
                        SalesInvoiceDOC := RecSalesCreditMemo1."No.";
                        CustomerNo := RecSalesCreditMemo1."Sell-to Customer No.";
                        RecRef.GetTable(RecSalesCreditMemo1);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Credit Note", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    End;
                end;
            end;
        end;
        JObj.Add('Invoice', InvoiceBase64);
        JObj.Add('Shipment', ShipmentBase64);
        JObj.Add('InvoiceDoc', SalesInvoiceDOC);
        JObj.Add('ShipmentDoc', SalesShipmentDOC);
        JObj.Add('Posting Date', Postingdate);
        JObj.Add('CustomerNo', CustomerNo);
        exit(Base64.ToBase64(Format(JObj)));
    end;

    [ServiceEnabled]
    procedure Purchasetotal(DocNo: Code[20]): Text
    Var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        TaxTransValue1: Record "Tax Transaction Value";
        TaxComponentName1: Text;
        CGST_Amt2: Decimal;
        SGST_Amt2: Decimal;
        IGST_Amt2: Decimal;
        IgstAmount: Decimal;
        CgstAmount: Decimal;
        SgstAmount: Decimal;
        TDSAmount: Decimal;
        GrossAmt: Decimal;
        GSTSetup1: Record "GST Setup";
        TDSSetup1: Record "TDS Setup";
        JsonObject: JsonObject;
        Base64: Codeunit "Base64 Convert";
    Begin

        Clear(IgstAmount);
        Clear(CgstAmount);
        Clear(SgstAmount);
        Clear(GrossAmt);
        GSTSetup1.Get();//PT
        PurchaseLine.Reset();
        PurchaseLine.SetRange("Document No.", DocNo);
        PurchaseLine.SetFilter("No.", '<>%1', '');
        if PurchaseLine.FindFirst() then
            repeat
                GrossAmt += PurchaseLine.Amount;
                TaxTransValue1.Reset();
                TaxTransValue1.SetRange("Tax Type", GSTSetup1."GST Tax Type");
                TaxTransValue1.SetRange("Tax Record ID", "PurchaseLine".RecordId());
                TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
                TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                if TaxTransValue1.FindFirst() then
                    repeat
                        TaxComponentName1 := TaxTransValue1.GetAttributeColumName();
                        case TaxComponentName1 of
                            'IGST':
                                begin
                                    evaluate(IGST_Amt2, TaxTransValue1."Column Value");
                                    IgstAmount += IGST_Amt2;
                                end;
                            'CGST':
                                begin
                                    evaluate(CGST_Amt2, TaxTransValue1."Column Value");
                                    CgstAmount += CGST_Amt2;
                                end;
                            'SGST':
                                begin
                                    evaluate(SGST_Amt2, TaxTransValue1."Column Value");
                                    SgstAmount += SGST_Amt2;
                                end;
                        end;
                    until TaxTransValue1.Next() = 0;
                TDSSetup1.Get;
                TaxTransValue1.Reset();
                TaxTransValue1.SetRange("Tax Type", TDSSetup1."Tax Type");
                TaxTransValue1.SetRange("Tax Record ID", PurchaseLine.RecordId());
                TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
                TaxTransValue1.SetRange("Value ID", 7);
                if TaxTransValue1.FindFirst() then
                    repeat
                        TDSAmount += TaxTransValue1.Amount
                        Until TaxTransValue1.Next() = 0;
            Until PurchaseLine.Next() = 0;
        JsonObject.Add('Gross Amount', GrossAmt);
        JsonObject.Add('IGST', Round(IgstAmount, 0.01));
        JsonObject.Add('CGST', Round(CgstAmount, 0.01));
        JsonObject.Add('SGST', Round(SgstAmount, 0.01));
        JsonObject.Add('TDS', Round(TDSAmount, 1));
        JsonObject.Add('Total Payable', (GrossAmt + Round(IGSTamount, 0.01) + Round(CgstAmount, 0.01) + Round(SgstAmount, 0.01) - Round(TDSAmount, 1)));
        JsonObject.Add('Total Invoice Amt', (GrossAmt + Round(IGSTamount, 0.01) + Round(CgstAmount, 0.01) + Round(SgstAmount, 0.01)));

        Exit(Base64.ToBase64(Format(JsonObject)));

    End;


    [ServiceEnabled]
    procedure PostPurchase(DocNo: Code[20]; DefaultOption: Integer; sFPL_User_ID: text[20]): Text
    var
        G_LEntry: Record "G/L Entry";
        Purchasereceipt: Record "Purch. Rcpt. Header";
        Purchasereceipt2: Record "Purch. Rcpt. Header";
        PurchaeInvoice: Record "Purch. Inv. Header";
        PurchaeInvoice2: Record "Purch. Inv. Header";
        PurchasereturnShip: Record "Return Shipment Header";
        PurchasereturnShip2: Record "Return Shipment Header";
        PurchCreditMemo: Record "Purch. Cr. Memo Hdr.";
        PostingSelectionManagment: Codeunit "Posting Selection Management";
        PurcHeader: Record "Purchase Header";
        PurchaseHeader: Record "Purchase Header";
        UserSetupManagement: Codeunit "User Setup Management";
        ConfirmManagement: Codeunit "Confirm Management";
        Selection: Integer;
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        Base64: Codeunit "Base64 Convert";
        InvoiceBase64: Text;
        ShipmentBase64: Text;
        JObj: JsonObject;
        VehicleNo: Text;
        VendorCreNo: Text;
        VendorInvoiceNo: Text;
        InvoiceDOC: Text;
        ReceiptDoc: text;
        Postingdate: Date;
    begin
        if DefaultOption > 3 then
            DefaultOption := 3;
        if DefaultOption <= 0 then
            DefaultOption := 1;
        Clear(VehicleNo);
        PurcHeader.Reset();
        PurcHeader.SetRange("No.", DocNo);
        if PurcHeader.FindFirst() then
            PurchaseHeader.Copy(PurcHeader);

        case PurchaseHeader."Document Type" of
            PurchaseHeader."Document Type"::Order:
                begin
                    if PurchaseHeader."PO Type" in [PurchaseHeader."PO Type"::Goods] Then begin
                        PurchaseHeader.TESTFIELD("Brokerage Code");//PRU-VG1.0
                        PurchaseHeader.TESTFIELD("Rate Basis");//PRU-VG1.0
                    end;
                    if PurchaseHeader.Status = PurchaseHeader.Status::"Short Close" then
                        Error('You can not post the Entry in Short Closed PO, Please contact with Purchaser');
                    PurchaseHeader.TESTFIELD("Payment Terms Code");
                    UpdateShipandInvoice(PurchaseHeader.Receive, PurchaseHeader.Invoice);
                    //  UserSetupManagement.GetPurchaseInvoicePostingPolicy(PurchaseHeader.Receive, PurchaseHeader.Invoice);
                    case true of
                        not PurchaseHeader.Receive and not PurchaseHeader.Invoice:
                            begin
                                PurchaseHeader."SFPL User ID" := sFPL_User_ID;
                                PurchaseHeader.Receive := DefaultOption in [1, 3];
                                PurchaseHeader.Invoice := DefaultOption in [2, 3];
                            end;
                    // PurchaseHeader.Receive and not PurchaseHeader.Invoice:
                    //     if not ConfirmManagement.GetResponseOrDefault(GetReceiveConfirmationMessage(), true) then
                    //         exit(false);
                    // PurchaseHeader.Receive and PurchaseHeader.Invoice:
                    //     if not ConfirmManagement.GetResponseOrDefault(GetReceiveInvoiceConfirmationMessage(), true) then
                    //         exit(false);
                    end;
                end;
            PurchaseHeader."Document Type"::"Return Order":
                begin
                    UpdateShipandInvoice(PurchaseHeader.Ship, PurchaseHeader.Invoice);
                    //UserSetupManagement.GetPurchaseInvoicePostingPolicy(PurchaseHeader.Ship, PurchaseHeader.Invoice);
                    case true of
                        not PurchaseHeader.Ship and not PurchaseHeader.Invoice:
                            begin
                                PurchaseHeader."SFPL User ID" := sFPL_User_ID;
                                PurchaseHeader.Ship := DefaultOption in [1, 3];
                                PurchaseHeader.Invoice := DefaultOption in [2, 3];
                            end;
                    // PurchaseHeader.Ship and not PurchaseHeader.Invoice:
                    //     if not ConfirmManagement.GetResponseOrDefault(GetShipConfirmationMessage(), true) then
                    //         exit(false);
                    // PurchaseHeader.Ship and PurchaseHeader.Invoice:
                    //     if not ConfirmManagement.GetResponseOrDefault(GetShipInvoiceConfirmationMessage(), true) then
                    //         exit(false);
                    end;
                end;
            PurchaseHeader."Document Type"::Invoice, PurchaseHeader."Document Type"::"Credit Memo":
                begin
                    UpdateShipandInvoice(PurchaseHeader.Ship, PurchaseHeader.Invoice);
                    PurchaseHeader."SFPL User ID" := sFPL_User_ID;
                    //CheckUserCanInvoicePurchase();
                    // if not ConfirmManagement.GetResponseOrDefault(
                    //         GetPostConfirmationMessage(PurchaseHeader."Document Type" = PurchaseHeader."Document Type"::Invoice, WithPrint, WithEmail), true)
                    // then
                    //     exit(false);
                end;
            else
        // if not ConfirmManagement.GetResponseOrDefault(
        //         GetPostConfirmationMessage(Format(PurchaseHeader."Document Type"), WithPrint, WithEmail), true)
        // then
        //     exit(false);
        end;
        VehicleNo := PurchaseHeader."Vehicle No.";
        VendorCreNo := PurchaseHeader."Vendor Cr. Memo No.";
        VendorInvoiceNo := PurchaseHeader."Vendor Invoice No.";
        PurcHeader.Copy(PurchaseHeader);
        CODEUNIT.Run(CODEUNIT::"Purch.-Post", PurcHeader);
        If PurcHeader."Document Type" in [PurchaseHeader."Document Type"::Order, PurchaseHeader."Document Type"::Invoice] then begin
            if DefaultOption in [3] then begin
                PurchaeInvoice.Reset();
                If PurcHeader."Document Type" in [PurcHeader."Document Type"::Invoice] then
                    PurchaeInvoice.SetRange("Pre-Assigned No.", PurcHeader."No.")
                Else
                    PurchaeInvoice.SetRange("Order No.", PurcHeader."No.");

                PurchaeInvoice.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchaeInvoice.SetRange("Posting Date", PurcHeader."Posting Date");
                PurchaeInvoice.SetRange("Vendor Invoice No.", VendorInvoiceNo);
                if PurchaeInvoice.FindLast() then begin
                    G_LEntry.Reset();
                    G_LEntry.SetRange("Document No.", PurchaeInvoice."No.");
                    G_LEntry.SetRange("Posting Date", PurchaeInvoice."Posting Date");
                    G_LEntry.SetFilter("Source Code", '<>%1', 'INVTPCOST');
                    If G_LEntry.FindLast() Then Begin
                        InvoiceDOC := G_LEntry."Document No.";
                        Postingdate := G_LEntry."Posting Date";
                        RecRef.GetTable(G_LEntry);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Posted Voucher1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
                Purchasereceipt.Reset();
                Purchasereceipt.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                Purchasereceipt.SetRange("Order No.", PurcHeader."No.");
                Purchasereceipt.SetRange("Posting Date", PurcHeader."Posting Date");
                Purchasereceipt.SetRange("Vehicle No.", VehicleNo);
                If Purchasereceipt.FindLast() Then begin
                    Clear(TempBlob);
                    Purchasereceipt2.Reset();
                    Purchasereceipt2.SetRange("No.", Purchasereceipt."No.");
                    if Purchasereceipt2.FindFirst() then begin
                        ReceiptDoc := Purchasereceipt2."No.";
                        Postingdate := Purchasereceipt2."Posting Date";
                        RecRef.GetTable(Purchasereceipt2);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Purchase - Receipt1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [2] then begin
                PurchaeInvoice.Reset();
                If PurcHeader."Document Type" in [PurcHeader."Document Type"::Invoice] then
                    PurchaeInvoice.SetRange("Pre-Assigned No.", PurcHeader."No.")
                Else
                    PurchaeInvoice.SetRange("Order No.", PurcHeader."No.");
                PurchaeInvoice.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchaeInvoice.SetRange("Posting Date", PurcHeader."Posting Date");
                PurchaeInvoice.SetRange("Vendor Invoice No.", VendorInvoiceNo);
                if PurchaeInvoice.FindLast() then begin
                    G_LEntry.Reset();
                    G_LEntry.SetRange("Document No.", PurchaeInvoice."No.");
                    G_LEntry.SetRange("Posting Date", PurchaeInvoice."Posting Date");
                    G_LEntry.SetFilter("Source Code", '<>%1', 'INVTPCOST');
                    If G_LEntry.FindLast() Then Begin
                        InvoiceDOC := G_LEntry."Document No.";
                        Postingdate := G_LEntry."Posting Date";
                        RecRef.GetTable(G_LEntry);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Posted Voucher1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [1] then begin
                Purchasereceipt.Reset();
                Purchasereceipt.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                Purchasereceipt.SetRange("Order No.", DocNo);
                Purchasereceipt.SetRange("Posting Date", PurcHeader."Posting Date");
                Purchasereceipt.SetRange("Vehicle No.", VehicleNo);
                If Purchasereceipt.FindLast() Then begin
                    Purchasereceipt2.Reset();
                    Purchasereceipt2.SetRange("No.", Purchasereceipt."No.");
                    if Purchasereceipt2.FindFirst() then begin
                        ReceiptDoc := Purchasereceipt2."No.";
                        Postingdate := Purchasereceipt2."Posting Date";
                        RecRef.GetTable(Purchasereceipt2);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Purchase - Receipt1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;

                end;
            end;
        end;
        If PurcHeader."Document Type" in [PurchaseHeader."Document Type"::"Return Order", PurchaseHeader."Document Type"::"Credit Memo"] then begin
            if DefaultOption in [3] then begin
                PurchCreditMemo.Reset();
                if PurcHeader."Document Type" in [PurcHeader."Document Type"::"Credit Memo"] then
                    PurchCreditMemo.SetRange("Pre-Assigned No.", PurcHeader."No.")
                else
                    PurchCreditMemo.SetRange("Return Order No.", PurcHeader."No.");
                PurchCreditMemo.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchCreditMemo.SetRange("Posting Date", PurcHeader."Posting Date");
                PurchCreditMemo.SetRange("Vendor Cr. Memo No.", VendorCreNo);
                if PurchCreditMemo.FindLast() then begin
                    G_LEntry.Reset();
                    G_LEntry.SetRange("Document No.", PurchCreditMemo."No.");
                    G_LEntry.SetRange("Posting Date", PurcHeader."Posting Date");
                    G_LEntry.SetFilter("Source Code", '<>%1', 'INVTPCOST');
                    If G_LEntry.FindLast() Then Begin
                        InvoiceDOC := Format(G_LEntry."Document No.");
                        Postingdate := G_LEntry."Posting Date";
                        RecRef.GetTable(G_LEntry);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Posted Voucher1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
                PurchasereturnShip.Reset();
                PurchasereturnShip.SetCurrentKey("Buy-from Vendor No.", "Return Order No.", "Posting Date", "Vehicle No.");
                PurchasereturnShip.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchasereturnShip.SetRange("Return Order No.", PurcHeader."No.");
                PurchasereturnShip.SetRange("Posting Date", PurcHeader."Posting Date");
                PurchasereturnShip.SetRange("Vehicle No.", VehicleNo);
                If PurchasereturnShip.FindLast() Then begin
                    Clear(TempBlob);
                    PurchasereturnShip2.Reset();
                    PurchasereturnShip2.SetRange("No.", PurchasereturnShip."No.");
                    if PurchasereturnShip2.FindFirst() then begin
                        ReceiptDoc := PurchasereturnShip2."No.";
                        Postingdate := PurchasereturnShip2."Posting Date";
                        RecRef.GetTable(PurchasereturnShip2);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Purchase - Return Shipment", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [2] then begin
                PurchCreditMemo.Reset();
                if PurcHeader."Document Type" in [PurcHeader."Document Type"::"Credit Memo"] then
                    PurchCreditMemo.SetRange("Pre-Assigned No.", PurcHeader."No.")
                else
                    PurchCreditMemo.SetRange("Return Order No.", PurcHeader."No.");
                PurchCreditMemo.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchCreditMemo.SetRange("Posting Date", PurcHeader."Posting Date");
                PurchCreditMemo.SetRange("Vendor Cr. Memo No.", VendorCreNo);
                if PurchCreditMemo.FindLast() then begin
                    G_LEntry.Reset();
                    G_LEntry.SetRange("Document No.", PurchCreditMemo."No.");
                    G_LEntry.SetRange("Posting Date", PurcHeader."Posting Date");
                    G_LEntry.SetFilter("Source Code", '<>%1', 'INVTPCOST');
                    If G_LEntry.FindLast() Then Begin
                        InvoiceDOC := G_LEntry."Document No.";
                        Postingdate := G_LEntry."Posting Date";
                        RecRef.GetTable(G_LEntry);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Posted Voucher1", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        InvoiceBase64 := (Base64.ToBase64(Instr));
                    end;
                end;
            end;
            if DefaultOption in [1] then begin
                PurchasereturnShip.Reset();
                PurchasereturnShip.SetCurrentKey("Buy-from Vendor No.", "Return Order No.", "Posting Date");
                PurchasereturnShip.SetRange("Buy-from Vendor No.", PurcHeader."Buy-from Vendor No.");
                PurchasereturnShip.SetRange("Return Order No.", PurcHeader."No.");
                PurchasereturnShip.SetRange("Posting Date", PurcHeader."Posting Date");
                //PurchasereturnShip.SetRange("Vehicle No.", VehicleNo);
                If PurchasereturnShip.FindLast() Then begin
                    PurchasereturnShip2.Reset();
                    PurchasereturnShip2.SetRange("No.", PurchasereturnShip."No.");
                    if PurchasereturnShip2.FindFirst() then begin
                        ReceiptDoc := PurchasereturnShip2."No.";
                        Postingdate := PurchasereturnShip2."Posting Date";
                        Clear(TempBlob);
                        RecRef.GetTable(PurchasereturnShip2);
                        TempBlob.CreateOutStream(Outstr);
                        Report.SaveAs(Report::"Purchase - Return Shipment", '', ReportFormat::Pdf, Outstr, RecRef);
                        TempBlob.CreateInStream(Instr);
                        ShipmentBase64 := (Base64.ToBase64(Instr));
                    end;
                end;

            end;
        end;
        JObj.Add('Voucher', InvoiceBase64);
        JObj.Add('Receipt', ShipmentBase64);
        JObj.Add('VoucherDOC', InvoiceDOC);
        JObj.Add('ReceiptDOC', ReceiptDoc);
        JObj.Add('Posting Date', Postingdate);

        exit(Base64.ToBase64(Format(JObj)));
    end;


    procedure UpdateShipandInvoice(Var Shipto: Boolean; Var Invoice: Boolean)
    begin
        Shipto := False;
        Invoice := False;
    end;

    [ServiceEnabled]
    procedure GenerateEinvoice(doctype: Text; docno: Code[20]): Text
    var
        cuSalesPost: Codeunit 50025;
        Transfershipment: Record "Transfer Shipment Header";
        SalesInvoice: Record "Sales Invoice Header";
        SalesCredit: Record "Sales Cr.Memo Header";
    begin
        CLEAR(cuSalesPost);
        if doctype = 'Transfer' then begin
            Transfershipment.Reset();
            Transfershipment.SetRange("No.", docno);
            if Transfershipment.FindFirst() then begin
                cuSalesPost.GenerateTransferEInvoice(Transfershipment);
                Message('E-Invoice Generated');
            end;

        end;
        if doctype = 'SalesInvoice' then begin
            SalesInvoice.Reset();
            SalesInvoice.SetRange("No.", docno);
            if SalesInvoice.FindFirst() then begin
                cuSalesPost.GenerateSalesEInvoice(SalesInvoice);
                Message('E-Invoice Generated');
            end;
        end;
        if doctype = 'SalesCredit' then begin
            SalesCredit.Reset();
            SalesCredit.SetRange("No.", docno);
            if SalesCredit.FindFirst() then begin
                cuSalesPost.GenerateSalesCrMemoEInvoice(SalesCredit);
            end;

        end;
    end;


    [ServiceEnabled]
    procedure CancelEinvoice(doctype: Text; docno: Code[20]): Text
    var
        cuSalesPost: Codeunit 50025;
        Transfershipment: Record "Transfer Shipment Header";
        SalesInvoice: Record "Sales Invoice Header";
        SalesCredit: Record "Sales Cr.Memo Header";
    begin
        CLEAR(cuSalesPost);
        if doctype = 'Transfer' then begin
            Transfershipment.Reset();
            Transfershipment.SetRange("No.", docno);
            if Transfershipment.FindFirst() then begin
                cuSalesPost.CancelTransferEInvoice(Transfershipment);
                Message('E-Invoice Generated');
            end;

        end;
        if doctype = 'SalesInvoice' then begin
            SalesInvoice.Reset();
            SalesInvoice.SetRange("No.", docno);
            if SalesInvoice.FindFirst() then begin
                cuSalesPost.CancelSalesEInvoice(SalesInvoice);
                Message('E-Invoice Generated');
            end;
        end;
        if doctype = 'SalesCredit' then begin
            SalesCredit.Reset();
            SalesCredit.SetRange("No.", docno);
            if SalesCredit.FindFirst() then begin
                cuSalesPost.CancelSalesCrMemoEInvoice(SalesCredit);
            end;
        end;
    end;

    [ServiceEnabled]
    procedure GenerateEWayBill(doctype: Text; docno: Code[20]): Text
    var
        Cu50061: Codeunit 50061;
        EwayBillDate: DateTime;
        ValidUpto: DateTime;
        Transfershipment: Record "Transfer Shipment Header";
        SalesInvoice: Record "Sales Invoice Header";
        PurchCredit: Record "Purch. Cr. Memo Hdr.";

    begin
        CLEAR(Cu50061);
        if doctype = 'Transfer' then begin
            Transfershipment.Reset();
            Transfershipment.SetRange("No.", docno);
            if Transfershipment.FindFirst() then begin
                Cu50061.GenerateEwayBill(Transfershipment, Transfershipment."E-Way Bill No.", Transfershipment."E-Way Generated Date", ValidUpto);
                Message('EWayBill Generated');
            end;
        end;
        if doctype = 'SalesInvoice' then begin
            SalesInvoice.Reset();
            SalesInvoice.SetRange("No.", docno);
            if SalesInvoice.FindFirst() then begin
                Cu50061.GenerateEwayBill(SalesInvoice, SalesInvoice."E-Way Bill No.", SalesInvoice."E-Way Generated Date", ValidUpto);
                Message('EWayBill Generated');
            end;
        end;
        if doctype = 'PurCredit' then begin
            PurchCredit.Reset();
            PurchCredit.SetRange("No.", docno);
            if PurchCredit.FindFirst() then begin
                Cu50061.GenerateEwayBill(PurchCredit, PurchCredit."E-Way Bill No.", PurchCredit."E-Way Generated Date", ValidUpto);
                Message('EWayBill Generated');
            end;

        end;
    end;


    [ServiceEnabled]
    procedure CancelEWayBill(doctype: Text; docno: Code[20]): Text
    var
        Cu50061: Codeunit 50061;
        EwayBillDate: DateTime;
        ValidUpto: DateTime;
        Loc: Record Location;
        Transfershipment: Record "Transfer Shipment Header";
        SalesInvoice: Record "Sales Invoice Header";
        PurchCredit: Record "Purch. Cr. Memo Hdr.";
    begin
        CLEAR(Cu50061);
        if doctype = 'Transfer' then begin
            Transfershipment.Reset();
            Transfershipment.SetRange("No.", docno);
            if Transfershipment.FindFirst() then begin
                Loc.Get(Transfershipment."Transfer-from Code");
                Loc.TestField("GST Registration No.");
                //Transfershipment.TestField("Location GST Reg. No.");
                Transfershipment.TestField("E-Way Bill No.");
                if Transfershipment."Eway Cancel Reason" = Transfershipment."Eway Cancel Reason"::" " then
                    Error('Kindly Update %1', Transfershipment.FieldCaption("Eway Cancel Reason"));
                if Transfershipment."Eway Cancel Remarks" = '' then
                    Error('Kindly Update %1', Transfershipment.FieldCaption("Eway Cancel Remarks"));

                Cu50061.CancelEwayBill(Transfershipment, Transfershipment."E-Way Bill No.", Transfershipment."Eway Cancel Reason", Transfershipment."Eway Cancel Remarks",
                Loc."GST Registration No.", Transfershipment."E-Way Cancelled Date");
            end;

        end;
        if doctype = 'SalesInvoice' then begin
            SalesInvoice.Reset();
            SalesInvoice.SetRange("No.", docno);
            if SalesInvoice.FindFirst() then begin
                SalesInvoice.TestField("Location GST Reg. No.");
                SalesInvoice.TestField("E-Way Bill No.");
                if SalesInvoice."Eway Cancel Reason" = SalesInvoice."Eway Cancel Reason"::" " then
                    Error('Kindly Update %1', SalesInvoice.FieldCaption("Eway Cancel Reason"));
                if SalesInvoice."Eway Cancel Remarks" = '' then
                    Error('Kindly Update %1', SalesInvoice.FieldCaption("Eway Cancel Remarks"));
                Cu50061.CancelEwayBill(SalesInvoice, SalesInvoice."E-Way Bill No.", SalesInvoice."Eway Cancel Reason", SalesInvoice."Eway Cancel Remarks",
                SalesInvoice."Location GST Reg. No.", SalesInvoice."E-Way Cancelled Date");
            end;
        end;
        if doctype = 'PurCredit' then begin
            PurchCredit.Reset();
            PurchCredit.SetRange("No.", docno);
            if PurchCredit.FindFirst() then begin
                PurchCredit.TestField("E-Way Bill No.");
                if PurchCredit."Eway Cancel Reason" = PurchCredit."Eway Cancel Reason"::" " then
                    Error('Kindly Update %1', PurchCredit.FieldCaption("Eway Cancel Reason"));
                if PurchCredit."Eway Cancel Remarks" = '' then
                    Error('Kindly Update %1', PurchCredit.FieldCaption("Eway Cancel Remarks"));

                Cu50061.CancelEwayBill(PurchCredit, PurchCredit."E-Way Bill No.", PurchCredit."Eway Cancel Reason", PurchCredit."Eway Cancel Remarks",
                PurchCredit."Location GST Reg. No.", PurchCredit."E-Way Cancelled Date");
            end;

        end;
    end;

    [ServiceEnabled]
    procedure UpdateVehicle(docno: Code[20]; ewaybillno: text[50]): Text
    Var
        Cu50061: Codeunit 50061;
    begin
        Cu50061.UpdateVehicleDetails(docno, ewaybillno, false);
    end;


    [ServiceEnabled]
    procedure UpdateTransporter(docno: Code[20]; ewaybillno: text[50]): Text
    Var
        Cu50061: Codeunit 50061;
    begin
        Cu50061.UpdateVehicleDetails(docno, ewaybillno, true);
    end;

    [ServiceEnabled]
    procedure GetInvoiceReportWeb(DocumentNo: Code[20]; CustNo: Code[10]; PostingDate: date; UserID: Text; PrintdateTime: DateTime): Text
    var
        SalesInvoiceHeader1: Record "Sales Invoice Header";
        SalesInvoiceReport: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        SalesInvoiceHeader1.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        SalesInvoiceHeader1.SetRange("No.", DocumentNo);
        SalesInvoiceHeader1.SetRange("Bill-to Customer No.", CustNo);
        SalesInvoiceHeader1.SetRange("Posting Date", PostingDate);
        if SalesInvoiceHeader1.FindFirst() then begin
            RecRef.GetTable(SalesInvoiceHeader1);
            TempBlob.CreateOutStream(Outstr);
            SalesInvoiceReport.SetPrintIDandPrintTime(UserID, CurrentDateTime + (5 * 3600 + 30 * 60) * 1000);
            SalesInvoiceReport.SaveAs('', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    [ServiceEnabled]
    procedure GetDeliveryReportWeb(DocumentNo: Code[20]; CustNo: Code[10]; PostingDate: date): Text
    var
        SalesShipment: Record "Sales Shipment Header";
        //Report: Report "Sales Invoice New-GST";
        Base64: Codeunit "Base64 Convert";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
    Begin
        SalesShipment.Reset();
        //SalesInvoiceHeader1.SetCurrentKey("Bill-to Customer No.", "Posting Date");
        SalesShipment.SetRange("No.", DocumentNo);
        SalesShipment.SetRange("Bill-to Customer No.", CustNo);
        SalesShipment.SetRange("Posting Date", PostingDate);
        if SalesShipment.FindFirst() then begin
            RecRef.GetTable(SalesShipment);
            TempBlob.CreateOutStream(Outstr);
            Report.SaveAs(Report::"Sales Delivery Note", '', ReportFormat::Pdf, Outstr, RecRef);
            TempBlob.CreateInStream(Instr);
            Exit(Base64.ToBase64(Instr));
        end;
    End;

    procedure varifyGST(DocumentNo: Code[20])
    var
        TaxTransValue1: Record "Tax Transaction Value";
        GSTSetup1: Record "GST Setup";
        Sl: record "Sales Line";
    Begin
        Sl.RESET;
        Sl.SETRANGE("Document No.", DocumentNo);
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
    End;

    [ServiceEnabled]
    procedure DownloadRecordLink(DocumentType: Text; DocumentNo: Text): Text
    Var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        PurchaseCreditMemo: Record "Purch. Cr. Memo Hdr.";
        TransferShipment: Record "Transfer Shipment Header";
    Begin
        if DocumentType = 'Purchase' Then begin
            PurchaseCreditMemo.Reset();
            PurchaseCreditMemo.SetRange("No.", DocumentNo);
            If PurchaseCreditMemo.FindFirst() then begin
                RecordLink.SetRange("Record ID", PurchaseCreditMemo.RecordId);
                RecordLink.SetRange(Description, 'EwayBill Download');
                if RecordLink.FindFirst() then
                    Exit(RecordLink.URL1);
            end;
        end;
        if DocumentType = 'SalesInvoice' Then begin
            SalesInvoiceHeader.Reset();
            SalesInvoiceHeader.SetRange("No.", DocumentNo);
            If SalesInvoiceHeader.FindFirst() then begin
                RecordLink.SetRange("Record ID", SalesInvoiceHeader.RecordId);
                RecordLink.SetRange(Description, 'EwayBill Download');
                if RecordLink.FindFirst() then
                    Exit(RecordLink.URL1);
            end;
        end;
        if DocumentType = 'Transfer' Then begin
            TransferShipment.Reset();
            TransferShipment.SetRange("No.", DocumentNo);
            If TransferShipment.FindFirst() then begin
                RecordLink.SetRange("Record ID", TransferShipment.RecordId);
                RecordLink.SetRange(Description, 'EwayBill Download');
                if RecordLink.FindFirst() then
                    Exit(RecordLink.URL1);
            end;
        end;
    End;

    procedure PostTransferOrder(DocNo: Code[20]; PostShipment: boolean; PostReceipt: boolean; sFPL_User_ID: text[50]): Text
    var
        GenJnlPostPreview: Codeunit "Gen. Jnl.-Post Preview";
        TransferOrderPostReceipt: Codeunit "TransferOrder-Post Receipt";
        TransferOrderPostShipment: Codeunit "TransferOrder-Post Shipment";
        TransferOrderPostTransfer: Codeunit "TransferOrder-Post Transfer";
        TransHeader: Record "Transfer Header";
        GSTPreviewHandlar: Codeunit "GST Preview Handler";
        PostedTransferShipment: Record "Transfer Shipment Header";
        PostTramnsferreceipt: record "Transfer Receipt Header";
        PostTramnsferreceipt1: record "Transfer Receipt Header";
        RecRef: RecordRef;
        TempBlob: Codeunit "Temp Blob";
        Email: Codeunit Email;
        Outstr: OutStream;
        Instr: InStream;
        Base64: Codeunit "Base64 Convert";
        InvoiceBase64: Text;
        ShipmentBase64: Text;
        JObj: JsonObject;
        TransferOrderReport: Report "Transfer Order 2016";

    begin

        TransHeader.Reset();
        TransHeader.SetRange("No.", DocNo);
        if TransHeader.FindFirst() then begin
            TransHeader."SFPL User ID" := sFPL_User_ID;
            GSTPreviewHandlar.ClearBuffers();
            OnCodeOnBeforePostTransferOrder(TransHeader);
            if PostShipment then begin
                TransferOrderPostShipment.Run(TransHeader);
                // PostedTransferShipment.Reset();
                // PostedTransferShipment.SetCurrentKey("Posting Date", "No.");
                // PostedTransferShipment.SetRange("Transfer Order No.", DocNo);
                // PostedTransferShipment.SetRange("Posting Date", TransHeader."Posting Date");
                // If PostedTransferShipment.FindLast() Then begin
                //     RecRef.GetTable(PostedTransferShipment);
                //     TempBlob.CreateOutStream(Outstr);
                //     Report.SaveAs(Report::"Transfer Order 2016", '', ReportFormat::Pdf, Outstr, RecRef);
                //     TempBlob.CreateInStream(Instr);
                //     Exit((Base64.ToBase64(Instr)));
                // end;
            end;

            if PostReceipt then begin
                TransferOrderPostReceipt.Run(TransHeader);
                // PostTramnsferreceipt.Reset();
                // PostTramnsferreceipt.SetRange("Transfer Order No.", TransHeader."No.");
                // PostTramnsferreceipt.SetRange("Posting Date", TransHeader."Posting Date");
                // if PostTramnsferreceipt.FindLast() then begin
                //     PostTramnsferreceipt1.Reset();
                //     PostTramnsferreceipt1.SetRange("No.", PostTramnsferreceipt."No.");
                //     if PostTramnsferreceipt1.FindFirst() then begin
                //         RecRef.GetTable(PostTramnsferreceipt1);
                //         TempBlob.CreateOutStream(Outstr);
                //         Report.SaveAs(Report::"Transfer Receipt", '', ReportFormat::Pdf, Outstr, RecRef);
                //         TempBlob.CreateInStream(Instr);
                //         Exit((Base64.ToBase64(Instr)));
                //     end;
                // end;

            end;
        end;
    end;

    local procedure "OnCodeOnBeforePostTransferOrder"(TransHeader: Record "Transfer Header")
    var
        TransferLine_T1: Record "Transfer Line";
        TransferLine_123: Record "Transfer Line";
        DimensionSetEntry_123: Record "Dimension Set Entry";
        SLRec: Record "Transfer Line";
        SLRec1: Record "Transfer Line";
        LocaFrom: Record Location;
        LocTo: Record Location;
        GENLe: Record "General Ledger Setup";
        CompanyInfo: Record "Company Information";
        TaxTransValue1: Record "Tax Transaction Value";
        GSTSetup1: Record "GST Setup";
        TaxComponentName1: Text;
        StarTransferLine: Record "Transfer Line";
        RecItem: Record Item;
    begin
        GENLe.Get();
        CompanyInfo.Get;
        if GENLe."St Dt" <= TransHeader."Posting Date" then begin
            SLRec.Reset();
            SLRec.SetRange("Document No.", TransHeader."No.");
            SLRec.SetFilter(SLRec."Item No.", '<>%1', '');
            SLRec.SetFilter(SLRec."Transfer-from Code", '<>%1', 'IN-TRANSIT');
            if SLRec.FindFirst() then
                repeat
                    SLRec1.Reset();
                    SLRec1.SetRange("Document No.", SLRec."Document No.");
                    //SLRec1.SetFilter("Line No.", '<>%1', SLRec."Line No.");
                    SLRec1.SetFilter("Item No.", '<>%1', '');
                    SLRec1.SetFilter(SLRec1."Transfer-from Code", '<>%1', 'IN-TRANSIT');
                    if SLRec1.FindFirst() then
                        repeat
                            Clear(LocaFrom);
                            Clear(LocTo);
                            LocaFrom.get(SLRec1."Transfer-from Code");
                            LocTo.get(SLRec1."Transfer-to Code");
                            if LocaFrom."State Code" <> LocTo."State Code" then begin
                                if SLRec.Exempted <> SLRec1.Exempted then
                                    Error('Exempted are not same all line', SLRec1."Line No.");
                            END;
                            SLRec.Testfield(SLRec."GST Group Code");
                            SLRec.TestField(SLRec."HSN/SAC Code");
                        until SLRec1.Next() = 0;

                    SLRec.Testfield(SLRec."GST Group Code");
                    SLRec.TestField(SLRec."HSN/SAC Code");
                    Clear(LocaFrom);
                    Clear(LocTo);
                    LocaFrom.get(SLRec."Transfer-from Code");
                    LocTo.get(SLRec."Transfer-to Code");
                    if LocaFrom."State Code" <> LocTo."State Code" Then begin
                        GSTSetup1.Get;
                        TaxTransValue1.Reset();
                        TaxTransValue1.SetRange("Tax Type", GSTSetup1."GST Tax Type");
                        TaxTransValue1.SetRange("Tax Record ID", SLRec.RecordId());
                        TaxTransValue1.SetRange("Value Type", TaxTransValue1."Value Type"::COMPONENT);
                        //TaxTransValue1.SetFilter(Percent, '<>%1', 0);
                        if TaxTransValue1.IsEmpty then
                            Error('GST Must be Calculated');
                    end;
                until SLRec.Next() = 0;
        END;
        If CompanyInfo.SFPLCompany in [CompanyInfo.SFPLCompany::"Star Foods"] then begin
            StarTransferLine.Reset();
            StarTransferLine.SetFilter("Item No.", '<>%1', '');
            StarTransferLine.SetRange("Document No.", TransHeader."No.");
            if StarTransferLine.FindSet() then
                repeat
                    RecItem.Get(StarTransferLine."Item No.");
                    If RecItem."Item Type" = RecItem."Item Type"::Bird then begin
                        StarTransferLine.TestField("Alternate Quantity");
                        StarTransferLine.TestField("Alternate UOM");
                    end;
                Until StarTransferLine.Next() = 0;
        end;

        TransferLine_123.RESET;
        TransferLine_123.SETRANGE("Document No.", TransHeader."No.");
        IF TransferLine_123.FINDFIRST THEN
            REPEAT
                IF TransferLine_123."Shortcut Dimension 1 Code" <> TransHeader."Shortcut Dimension 1 Code" THEN
                    ERROR('Transfer lines %1 LOB Code is not match of Transfer header LOB Code', TransferLine_123."Line No.");
                IF TransferLine_123."Shortcut Dimension 2 Code" <> TransHeader."Shortcut Dimension 2 Code" THEN
                    ERROR('Transfer lines %1 Branch is not match of Transfer header Branch', TransferLine_123."Line No.");
                If CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna then
                    IF TransferLine_123."Shortcut Dimension 3 Code" <> TransHeader."Shortcut Dimension 3 Code" THEN
                        ERROR('Transfer lines %1 LOC Code is not match of Transfer header LOC Code', TransferLine_123."Line No.");
                IF TransferLine_123."Dimension Set ID" <> TransHeader."Dimension Set ID" THEN
                    ERROR('Transfer lines %1 dimension set id is not match of Transfer header dimension set id', TransferLine_123."Line No.");
                DimensionSetEntry_123.RESET;
                DimensionSetEntry_123.SETRANGE("Dimension Set ID", TransHeader."Dimension Set ID");
                IF DimensionSetEntry_123.FINDSET THEN
                    REPEAT
                        IF DimensionSetEntry_123."Dimension Code" = 'BRANCH' THEN BEGIN
                            IF DimensionSetEntry_123."Dimension Value Code" <> TransHeader."Shortcut Dimension 2 Code" THEN
                                ERROR('Transfer lines %1 Branch is not match of Transfer header Branch', TransferLine_123."Line No.");
                        END;
                        IF DimensionSetEntry_123."Dimension Code" = 'LOB' THEN BEGIN
                            IF DimensionSetEntry_123."Dimension Value Code" <> TransHeader."Shortcut Dimension 1 Code" THEN
                                ERROR('Transfer lines %1 LOB Code is not match of Transfer header LOB Code', TransferLine_123."Line No.");
                        END;
                        If CompanyInfo.SFPLCompany = CompanyInfo.SFPLCompany::Sampoorna then
                            IF DimensionSetEntry_123."Dimension Code" = 'LOC' THEN BEGIN
                                IF DimensionSetEntry_123."Dimension Value Code" <> TransHeader."Shortcut Dimension 3 Code" THEN
                                    ERROR('Transfer lines %1 LOC Code is not match of Transfer header LOC Code', TransferLine_123."Line No.");
                            END;
                    UNTIL DimensionSetEntry_123.NEXT = 0;
            UNTIL TransferLine_123.NEXT = 0;
        ///Pru_gk DMV_.01
    end;

    [ServiceEnabled]
    procedure TransferOrderReleaseOpen(DocNo: Code[20]; Open: Boolean; Released: Boolean)
    var
        TransferHeader: Record "Transfer Header";
        ReleaseTransferDoc: Codeunit "Release Transfer Document";
    Begin
        TransferHeader.Get(DocNo);
        if Released Then Begin
            if TransferHeader.Status <> TransferHeader.Status::Released then begin
                CODEUNIT.Run(CODEUNIT::"Release Transfer Document", TransferHeader);
                Commit();
            end;
        End else begin
            ReleaseTransferDoc.Reopen(TransferHeader);
        end;
    end;

    [ServiceEnabled]
    procedure SaleCopyDocument(FromDocType1: Text; FromDocNo: Code[20]; SalesHeaderNo: Code[20])
    var
        ExactCostReversingMandatory: Boolean;
        SalesSetup: Record "Sales & Receivables Setup";
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        SalesHeader1: Record "Sales Header";
        SalesHeader: Record "Sales Header";
        FromDocType: Enum "Sales Document Type From";
    begin
        SalesHeader1.Reset();
        SalesHeader1.SetRange("No.", SalesHeaderNo);
        if SalesHeader1.FindFirst() then
            SalesHeader.Get(SalesHeader1."Document Type", SalesHeader1."No.");

        case FromDocType1 of
            'Posted Invoice':
                FromDocType := FromDocType::"Posted Invoice";
            'Posted Shipment':
                FromDocType := FromDocType::"Posted Shipment";
            'Order':
                FromDocType := FromDocType::Order;
            'Posted Credit Memo':
                FromDocType := FromDocType::"Posted Credit Memo";
        end;
        SalesSetup.Get();
        ExactCostReversingMandatory := SalesSetup."Exact Cost Reversing Mandatory";

        CopyDocMgt.SetProperties(
          true, false, false, false, false, ExactCostReversingMandatory, false);

        CopyDocMgt.CopySalesDoc(FromDocType, FromDocNo, SalesHeader);
    end;

    [ServiceEnabled]
    procedure PurchaseCopyDocument(FromDocType1: Text; FromDocNo: Code[20]; PurchaseHeaderNo: Code[20])
    var
        ExactCostReversingMandatory: Boolean;
        PurchSetup: Record "Purchases & Payables Setup";
        CopyDocMgt: Codeunit "Copy Document Mgt.";
        PurchaseHeader1: Record "Purchase Header";
        PurchaseHeader: Record "Purchase Header";
        FromDocType: Enum "Purchase Document Type From";
    begin
        PurchaseHeader1.Reset();
        PurchaseHeader1.SetRange("No.", PurchaseHeaderNo);
        if PurchaseHeader1.FindFirst() then
            PurchaseHeader.Get(PurchaseHeader1."Document Type", PurchaseHeader1."No.");

        case FromDocType1 of
            'Posted Invoice':
                FromDocType := FromDocType::"Posted Invoice";
            'Posted Receipt':
                FromDocType := FromDocType::"Posted Receipt";
            'Order':
                FromDocType := FromDocType::Order;
            'Posted Credit Memo':
                FromDocType := FromDocType::"Posted Credit Memo";
        end;
        PurchSetup.Get();
        CopyDocMgt.SetProperties(
          true, false, false, false, false, PurchSetup."Exact Cost Reversing Mandatory", false);
        //CopyDocMgt.SetArchDocVal(FromDocNoOccurrence, FromDocVersionNo);

        //OnPreReportOnBeforeCopyPurchaseDoc(CopyDocMgt, CurrReport.UseRequestPage(), IncludeHeader, RecalculateLines);

        CopyDocMgt.CopyPurchDoc(FromDocType, FromDocNo, PurchaseHeader);

        //OnAfterOnPreReport(FromDocType, FromDocNo, PurchHeader);
    end;

    [ServiceEnabled]
    procedure SaleGetPostedline(DocType: Text; DocumentNo: Code[20]; Shipment: Code[20]; shipmentline: Integer)
    var
        SalesGetShpt: Codeunit "Sales-Get Shipment";
        SalesReturnGetShpt: Codeunit "Sales-Get Return Receipts";
        recSalesHeader: Record "Sales Header";
        SalesHeader: Record "Sales Header";
        recSalesShipment: record "Sales Shipment Line";
        RecReturnReceipt: Record "Return Receipt Line";

    Begin
        recSalesHeader.Reset();
        recSalesHeader.SetRange("No.", DocumentNo);
        if recSalesHeader.FindFirst() then
            SalesHeader.get(recSalesHeader."Document Type", recSalesHeader."No.");
        if DocType = 'Invoice' then begin
            recSalesShipment.Reset();
            recSalesShipment.SetCurrentKey("Bill-to Customer No.");
            recSalesShipment.SetRange("Document No.", Shipment);
            recSalesShipment.SetRange("Line No.", shipmentline);
            recSalesShipment.SetRange("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");
            recSalesShipment.SetRange("Currency Code", SalesHeader."Currency Code");
            recSalesShipment.SetFilter("Qty. Shipped Not Invoiced", '<>%1', 0);
            if recSalesShipment.FindFirst() then begin
                SalesGetShpt.SetSalesHeader(SalesHeader);
                SalesGetShpt.CreateInvLines(recSalesShipment);
            end;

            if DocType = 'CreditMemo' then begin
                RecReturnReceipt.Reset();
                RecReturnReceipt.SetCurrentKey("Bill-to Customer No.");
                RecReturnReceipt.SetRange("Document No.", Shipment);
                RecReturnReceipt.SetRange("Line No.", shipmentline);
                RecReturnReceipt.SetRange("Bill-to Customer No.", SalesHeader."Bill-to Customer No.");
                RecReturnReceipt.SetRange("Currency Code", SalesHeader."Currency Code");
                RecReturnReceipt.SetFilter("Return Qty. Rcd. Not Invd.", '<>%1', 0);
                if RecReturnReceipt.FindFirst() then begin
                    SalesReturnGetShpt.SetSalesHeader(SalesHeader);
                    SalesReturnGetShpt.CreateInvLines(RecReturnReceipt);
                end;
            end;
        end;

    End;

    [ServiceEnabled]
    procedure PurchaseGetPostedline(DocType: Text; DocumentNo: Code[20]; Receipt: Code[20]; Receiptline: Integer)
    var
        PurchaseGetreceipt: Codeunit "Purch.-Get Receipt";
        PurchaseGetReturnShip: Codeunit "Purch.-Get Return Shipments";
        recPurchHeader: Record "Purchase Header";
        PurchHeader: Record "Purchase Header";
        recPurchreceipt: record "Purch. Rcpt. Line";
        RecPurchReturnShip: Record "Return Shipment Line";

    Begin
        recPurchHeader.Reset();
        recPurchHeader.SetRange("No.", DocumentNo);
        if recPurchHeader.FindFirst() then
            PurchHeader.get(recPurchHeader."Document Type", recPurchHeader."No.");
        if DocType = 'Invoice' then begin
            recPurchreceipt.Reset();
            recPurchreceipt.SetCurrentKey("Pay-to Vendor No.");
            recPurchreceipt.SetRange("Document No.", Receipt);
            recPurchreceipt.SetRange("Line No.", Receiptline);
            recPurchreceipt.SetRange("Pay-to Vendor No.", PurchHeader."Pay-to Vendor No.");
            recPurchreceipt.SetRange("Buy-from Vendor No.", PurchHeader."Buy-from Vendor No.");
            recPurchreceipt.SetRange("Currency Code", PurchHeader."Currency Code");
            recPurchreceipt.SetFilter("Qty. Rcd. Not Invoiced", '<>%1', 0);
            if recPurchreceipt.FindFirst() then begin
                //recPurchreceipt.Get(Receipt, Receiptline);
                PurchaseGetreceipt.SetPurchHeader(PurchHeader);
                PurchaseGetreceipt.CreateInvLines(recPurchreceipt);
            end;
        end;
        if DocType = 'CreditMemo' then begin
            RecPurchReturnShip.Reset();
            RecPurchReturnShip.SetCurrentKey("Pay-to Vendor No.");
            RecPurchReturnShip.SetRange("Document No.", Receipt);
            RecPurchReturnShip.SetRange("Line No.", Receiptline);
            RecPurchReturnShip.SetRange("Pay-to Vendor No.", PurchHeader."Pay-to Vendor No.");
            RecPurchReturnShip.SetRange("Buy-from Vendor No.", PurchHeader."Buy-from Vendor No.");
            RecPurchReturnShip.SetRange("Currency Code", PurchHeader."Currency Code");
            RecPurchReturnShip.SetFilter("Return Qty. Shipped Not Invd.", '<>%1', 0);
            if RecPurchReturnShip.FindFirst() then begin
                PurchaseGetReturnShip.SetPurchHeader(PurchHeader);
                PurchaseGetReturnShip.CreateInvLines(RecPurchReturnShip);
            end;
        end;

    End;

    [ServiceEnabled]
    procedure AttachedGateEntry("SourceType": Text; "SourceNo": Code[20]; "EntryType": Text; "GateEntryNo": Code[20]; "LineNo": Integer)
    var
        GateEntryAttachment: Record "Gate Entry Attachment";
        SourceTypeEnum: Enum "Gate Entry Source Type";
        EntryTypeEnum: Enum "Gate Entry Type";
    Begin

        case SourceType of
            'Purchase Order':
                SourceTypeEnum := SourceTypeEnum::"Purchase Order";
            'Purchase Return Shipment':
                SourceTypeEnum := SourceTypeEnum::"Purchase Return Shipment";
            'Sales Return Order':
                SourceTypeEnum := SourceTypeEnum::"Sales Return Order";
            'Sales Shipment':
                SourceTypeEnum := SourceTypeEnum::"Sales Shipment";
            'Transfer Receipt':
                SourceTypeEnum := SourceTypeEnum::"Transfer Receipt";
            'Transfer Shipment':
                SourceTypeEnum := SourceTypeEnum::"Transfer Shipment";
        end;
        case EntryType of
            'Inward':
                EntryTypeEnum := EntryTypeEnum::Inward;
            'Outward':
                EntryTypeEnum := EntryTypeEnum::Outward;
        End;
        GateEntryAttachment.Init();
        GateEntryAttachment."Source Type" := SourceTypeEnum;
        GateEntryAttachment."Source No." := "SourceNo";
        GateEntryAttachment."Entry Type" := EntryTypeEnum;
        GateEntryAttachment."Gate Entry No." := "GateEntryNo";
        GateEntryAttachment."Line No." := "LineNo";
        //GateEntryAttachment."Purchase Invoice No." := "No.";
        GateEntryAttachment.Insert();
    End;

    [ServiceEnabled]
    procedure SendPurchaseApprovalReqeust(DocNo: Code[20])

    var
        ApprovalsMgmt: Codeunit 1535;
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("No.", DocNo);
        if PurchaseHeader.FindFirst() then;
        if ApprovalsMgmt.CheckPurchaseApprovalPossible(PurchaseHeader) then
            ApprovalsMgmt.OnSendPurchaseDocForApproval(PurchaseHeader);
    end;

    [ServiceEnabled]
    procedure CancelApprovalPurchase(DocNo: Code[20])
    var
        ApprovalsMgmt: Codeunit 1535;
        WorkflowWebhookMgt: Codeunit "Workflow Webhook Management";
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("No.", DocNo);
        if PurchaseHeader.FindFirst() then;
        ApprovalsMgmt.OnCancelPurchaseApprovalRequest(PurchaseHeader);
        WorkflowWebhookMgt.FindAndCancel(PurchaseHeader.RecordId);
    end;

    [ServiceEnabled]
    procedure ReopenPurchase(DocNo: Code[20])
    var
        ReleasePurchDoc: Codeunit "Release Purchase Document";
        PurchaseHeader: Record "Purchase Header";
    begin
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("No.", DocNo);
        if PurchaseHeader.FindFirst() then;
        ReleasePurchDoc.PerformManualReopen(PurchaseHeader);
        //CurrPage.PurchLines.PAGE.ClearTotalPurchaseHeader();
    end;

    procedure GetChargeItemLineSales(SalesDoc: Code[20]; LineNo: Integer)
    var
        ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)";
        AssignItemChargeSales: Codeunit "Item Charge Assgnt. (Sales)";
        ItemChargeAssgntLineAmt: Decimal;
        SalesLine: Record "Sales Line";
        SalesHeader: Record "Sales Header";
        Currency: Record Currency;
        CreditDocType: Boolean;
        ItemChargeAssignmentErr: Label 'You can only assign Item Charges for Line Types of Charge (Item).';
    begin
        SalesLine.Reset();
        SalesLine.SetRange("Document No.", SalesDoc);
        SalesLine.SetRange("Line No.", LineNo);
        if SalesLine.FindFirst() then begin
            if SalesLine.Type <> SalesLine.Type::"Charge (Item)" then begin
                Error(ItemChargeAssignmentErr);
            end;
            SalesHeader.Get(SalesLine."Document Type", SalesLine."Document No.");
            if SalesHeader."Currency Code" = '' then
                Currency.InitRoundingPrecision()
            else
                Currency.Get(SalesHeader."Currency Code");
            if (SalesLine."Inv. Discount Amount" = 0) and (SalesLine."Line Discount Amount" = 0) and
          (not SalesHeader."Prices Including VAT")
       then
                ItemChargeAssgntLineAmt := SalesLine."Line Amount"
            else
                if SalesHeader."Prices Including VAT" then
                    ItemChargeAssgntLineAmt :=
                      Round((SalesLine."Line Amount" - SalesLine."Inv. Discount Amount") / (1 + SalesLine."VAT %" / 100), Currency."Amount Rounding Precision")
                else
                    ItemChargeAssgntLineAmt := (SalesLine."Line Amount" - SalesLine."Inv. Discount Amount");
            ItemChargeAssgntSales.Reset();
            ItemChargeAssgntSales.SetRange("Document Type", SalesLine."Document Type");
            ItemChargeAssgntSales.SetRange("Document No.", SalesLine."Document No.");
            ItemChargeAssgntSales.SetRange("Document Line No.", SalesLine."Line No.");
            ItemChargeAssgntSales.SetRange("Item Charge No.", SalesLine."No.");
            if not ItemChargeAssgntSales.FindLast() then begin
                ItemChargeAssgntSales."Document Type" := SalesLine."Document Type";
                ItemChargeAssgntSales."Document No." := SalesLine."Document No.";
                ItemChargeAssgntSales."Document Line No." := SalesLine."Line No.";
                ItemChargeAssgntSales."Item Charge No." := SalesLine."No.";
                ItemChargeAssgntSales."Unit Cost" :=
                  Round(ItemChargeAssgntLineAmt / SalesLine.Quantity, Currency."Unit-Amount Rounding Precision");
            end;
            CreditDocType := SalesLine."Document Type" in [SalesLine."Document Type"::"Return Order", SalesLine."Document Type"::"Credit Memo"];
            if CreditDocType then
                AssignItemChargeSales.CreateDocChargeAssgn(ItemChargeAssgntSales, SalesLine."Return Receipt No.")
            else
                AssignItemChargeSales.CreateDocChargeAssgn(ItemChargeAssgntSales, SalesLine."Shipment No.");
            Clear(AssignItemChargeSales);
            Commit();
        end;
    end;

    procedure GetChargeItemLinePurchase(PurchDoc: Code[20]; LineNo: Integer)
    var
        ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
        ItemChargeAssgnts: Page "Item Charge Assignment (Purch)";
        PurchLine: Record "Purchase Line";
        PurchHea: Record "Purchase Header";
        Currency: Record Currency;
        ItemChargeAssgntLineAmt: Decimal;
        IsHandled: Boolean;
        ItemChargeAssignmentErr: Label 'You can only assign Item Charges for Line Types of Charge (Item).';
    begin

        PurchLine.Reset();
        PurchLine.SetRange("Document No.", PurchDoc);
        PurchLine.SetRange("Line No.", LineNo);
        if PurchLine.FindFirst() then begin
            PurchLine.TestField("No.");
            PurchLine.TestField(Quantity);
            if PurchLine.Type <> PurchLine.Type::"Charge (Item)" then begin
                Error(ItemChargeAssignmentErr);
            end;

            PurchHea.Get(PurchLine."Document Type", PurchLine."Document No.");
            if PurchHea."Currency Code" = '' then
                Currency.InitRoundingPrecision()
            else
                Currency.Get(PurchHeader."Currency Code");
            if (PurchLine."Inv. Discount Amount" = 0) and
               (PurchLine."Line Discount Amount" = 0) and
               (not PurchHeader."Prices Including VAT")
            then
                ItemChargeAssgntLineAmt := PurchLine."Line Amount"
            else
                if PurchHeader."Prices Including VAT" then
                    ItemChargeAssgntLineAmt :=
                      Round((PurchLine."Line Amount" - PurchLine."Inv. Discount Amount") / (1 + PurchLine."VAT %" / 100), Currency."Amount Rounding Precision")
                else
                    ItemChargeAssgntLineAmt := (PurchLine."Line Amount" - PurchLine."Inv. Discount Amount");

            ItemChargeAssgntPurch.Reset();
            ItemChargeAssgntPurch.SetRange("Document Type", PurchLine."Document Type");
            ItemChargeAssgntPurch.SetRange("Document No.", PurchLine."Document No.");
            ItemChargeAssgntPurch.SetRange("Document Line No.", PurchLine."Line No.");
            ItemChargeAssgntPurch.SetRange("Item Charge No.", PurchLine."No.");
            if not ItemChargeAssgntPurch.FindLast() then begin
                ItemChargeAssgntPurch."Document Type" := PurchLine."Document Type";
                ItemChargeAssgntPurch."Document No." := PurchLine."Document No.";
                ItemChargeAssgntPurch."Document Line No." := PurchLine."Line No.";
                ItemChargeAssgntPurch."Item Charge No." := PurchLine."No.";
                ItemChargeAssgntPurch."Unit Cost" :=
                  Round(ItemChargeAssgntLineAmt / PurchLine.Quantity,
                    Currency."Unit-Amount Rounding Precision");
            end;

            IsHandled := false;
            // OnShowItemChargeAssgntOnBeforeCalcItemCharge(Rec, ItemChargeAssgntLineAmt, Currency, IsHandled, ItemChargeAssgntPurch);
            if not IsHandled then
                ItemChargeAssgntLineAmt :=
                    Round(ItemChargeAssgntLineAmt * (PurchLine."Qty. to Invoice" / PurchLine.Quantity), Currency."Amount Rounding Precision");

            if (PurchLine."Document Type" in [PurchLine."Document Type"::"Return Order", PurchLine."Document Type"::"Credit Memo"]) then
                AssignItemChargePurch.CreateDocChargeAssgnt(ItemChargeAssgntPurch, PurchLine."Return Shipment No.")
            else
                AssignItemChargePurch.CreateDocChargeAssgnt(ItemChargeAssgntPurch, PurchLine."Receipt No.");
            Clear(AssignItemChargePurch);
            Commit();
        end;
    end;

    procedure PostItemChargeAssignment(SourceDoc: Code[20]; SourceLine: Integer; GetType: text; ChargeDocNo: Code[20]; ChargeLineNo: Integer; AssignmentType: Text)
    var
        ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)";
        ItemChargeAssgntPurch1: Record "Item Charge Assignment (Purch)";
        ItemChargeAssgntSales1: Record "Item Charge Assignment (Sales)";
        PurcLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        UnitCost: Decimal;
        NextLine: Integer;

    begin
        if AssignmentType = 'Purchase' then begin

            PurcLine.Reset();
            PurcLine.SetRange("Document No.", SourceDoc);
            PurcLine.SetRange("Line No.", SourceLine);
            if PurcLine.FindFirst() then begin
                UnitCost := PurcLine."Unit Cost";
                Clear(ItemChargeAssgntPurch);
                ItemChargeAssgntPurch.Init();
                ItemChargeAssgntPurch."Document No." := SourceDoc;
                ItemChargeAssgntPurch."Document Type" := PurcLine."Document Type";
                ItemChargeAssgntPurch."Document Line No." := PurcLine."Line No.";
                ItemChargeAssgntPurch."Item Charge No." := PurcLine."No.";
            end;
        end;
        if AssignmentType = 'Sale' then begin
            SalesLine.Reset();
            SalesLine.SetRange("Document No.", SourceDoc);
            SalesLine.SetRange("Line No.", SourceLine);
            if SalesLine.FindFirst() then begin
                UnitCost := SalesLine."Unit Price";
                Clear(ItemChargeAssgntSales);
                ItemChargeAssgntSales.Init();
                ItemChargeAssgntSales."Document No." := SourceDoc;
                ItemChargeAssgntSales."Document Type" := SalesLine."Document Type";
                ItemChargeAssgntSales."Document Line No." := SalesLine."Line No.";
                ItemChargeAssgntSales."Item Charge No." := SalesLine."No.";
                //ItemChargeAssgntSales."Line No." := NextLine;
                //ItemChargeAssgntSales.Insert();
            end;
        end;
        if AssignmentType = 'Purchase' then begin
            ItemChargeAssgntPurch.Reset();
            ItemChargeAssgntPurch.SetRange("Document No.", SourceDoc);
            ItemChargeAssgntPurch.SetRange("Document Line No.", PurcLine."Line No.");
            ItemChargeAssgntPurch.SetRange("Document Type", PurcLine."Document Type");
            ItemChargeAssgntPurch.SetRange("Item Charge No.", PurcLine."No.");
            if ItemChargeAssgntPurch.FindLast() Then;
        end;
        if AssignmentType = 'Sale' then begin
            ItemChargeAssgntSales.SetRange("Document No.", SourceDoc);
            ItemChargeAssgntSales.SetRange("Document Type", SalesLine."Document Type");
            ItemChargeAssgntSales.SetRange("Document Line No.", SalesLine."Line No.");
            ItemChargeAssgntSales.SetRange("Item Charge No.", SalesLine."No.");
            if ItemChargeAssgntSales.FindLast() then;
        end;
        case GetType of
            'GetreceiptLine':
                GetreceiptLine(ChargeDocNo, ChargeLineNo, UnitCost, ItemChargeAssgntPurch);
            'GetReturnReceiptLine':
                GetReturnReceiptLine(ChargeDocNo, ChargeLineNo, UnitCost, AssignmentType, ItemChargeAssgntPurch, ItemChargeAssgntSales);
            'GetShipmentLine':
                GetShipmentLine(ChargeDocNo, ChargeLineNo, UnitCost, AssignmentType, ItemChargeAssgntPurch, ItemChargeAssgntSales);
            'GetTransferReceiptLine':
                GetTransferReceiptLine(ChargeDocNo, ChargeLineNo, UnitCost, ItemChargeAssgntPurch);
            'GetReturnShipmentLine':
                GetReturnShipmentLine(ChargeDocNo, ChargeLineNo, UnitCost, ItemChargeAssgntPurch);

        end;
        Commit();
    end;

    [ServiceEnabled]
    procedure SuggestAssgnmt(DocNo: Code[20]; LineNo: Integer; TotalQtyToAssign: Decimal; TotalAmtToAssign: Decimal; TotalQtyToHandle: Decimal; TotalAmtToHandle: Decimal; SelectionTxt: Text)
    var
        ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        ItemChargeAssigment: Codeunit "Item Charge Assgnt. (Purch.)";
        PurchLine: Record "Purchase Line";
        Selection: Integer;
        //SelectionTxt: Text;
        SuggestItemChargeMenuTxt: Text;
        SuggestItemChargeMessageTxt: Text;
        IsHandled: Boolean;
    begin
        PurchLine.Reset();
        PurchLine.SetRange("Document No.", DocNo);
        PurchLine.SetRange("Line No.", LineNo);
        if PurchLine.FindFirst() then begin
            PurchLine.TestField("Qty. to Invoice");
            ItemChargeAssgntPurch.SetRange("Document Type", PurchLine."Document Type");
            ItemChargeAssgntPurch.SetRange("Document No.", PurchLine."Document No.");
            ItemChargeAssgntPurch.SetRange("Document Line No.", PurchLine."Line No.");
        end;
        if ItemChargeAssgntPurch.IsEmpty() then
            exit;

        ItemChargeAssgntPurch.SetRange("Applies-to Doc. Type", ItemChargeAssgntPurch."Applies-to Doc. Type"::"Transfer Receipt");


        ItemChargeAssgntPurch.SetRange("Applies-to Doc. Type");


        ItemChargeAssigment.AssignItemCharges(PurchLine, TotalQtyToAssign, TotalAmtToAssign, TotalQtyToHandle, TotalAmtToHandle, SelectionTxt);
    end;

    [ServiceEnabled]
    procedure SuggestAssgmentSales(DocNo: Code[20]; LineNo: Integer; TotalQtyToAssign: Decimal; TotalAmtToAssign: Decimal; TotalQtyToHandle: Decimal; TotalAmtToHandle: Decimal; SelectionTxt: Text)
    var
        AssignItemChargeSales: Codeunit "Item Charge Assgnt. (Sales)";
        ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)";
        SalesLine: Record "Sales Line";
    begin
        SalesLine.Reset();
        SalesLine.SetRange("Document No.", DocNo);
        SalesLine.SetRange("Line No.", LineNo);
        If SalesLine.FindFirst() Then begin
            SalesLine.TestField("Qty. to Invoice");
            ItemChargeAssgntSales.SetRange("Document Type", SalesLine."Document Type");
            ItemChargeAssgntSales.SetRange("Document No.", SalesLine."Document No.");
            ItemChargeAssgntSales.SetRange("Document Line No.", SalesLine."Line No.");
        end;
        if ItemChargeAssgntSales.IsEmpty() then
            exit;
        AssignItemChargeSales.AssignItemCharges(SalesLine, TotalQtyToAssign, TotalAmtToAssign, TotalQtyToHandle, TotalAmtToHandle, SelectionTxt);
    end;


    procedure GetreceiptLine(ChargeDocNo: Code[20]; ChargeLineNo: Integer; UnitCost: Decimal; ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)")
    var
        FromPurchRcptLine: Record "Purch. Rcpt. Line";
        ItemChargeAssgntPurch1: Record "Item Charge Assignment (Purch)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
    //UnitCost: Decimal;
    begin
        FromPurchRcptLine.Reset();
        FromPurchRcptLine.SetRange("Document No.", ChargeDocNo);
        FromPurchRcptLine.SetRange("Line No.", ChargeLineNo);
        if FromPurchRcptLine.FindFirst() then begin
            ItemChargeAssgntPurch."Unit Cost" := UnitCost;
            AssignItemChargePurch.CreateRcptChargeAssgnt(FromPurchRcptLine, ItemChargeAssgntPurch);
        end;
    end;

    procedure GetReturnReceiptLine(DocNo: Code[20]; LineNo: Integer; UnitCost: Decimal; AssignmentType1: Text; ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)"; ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)")
    var

        //ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        AssignItemChargeSales: Codeunit "Item Charge Assgnt. (Sales)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
        FromReturnRcptLine: Record "Return Receipt Line";
        AssignmentType: Option Sale,Purchase;
    begin
        Case AssignmentType1 of
            'Sale':
                AssignmentType := AssignmentType::Sale;
            'Purchase':
                AssignmentType := AssignmentType::Purchase;
        end;
        FromReturnRcptLine.Reset();
        FromReturnRcptLine.SetRange("Document No.", DocNo);
        FromReturnRcptLine.SetRange("Line No.", LineNo);
        //CurrPage.SetSelectionFilter(FromReturnRcptLine);
        if FromReturnRcptLine.FindFirst() then
            // CETAF start
            if AssignmentType = AssignmentType::Sale then begin
                ItemChargeAssgntSales."Unit Cost" := UnitCost;
                AssignItemChargeSales.CreateRcptChargeAssgnt(FromReturnRcptLine, ItemChargeAssgntSales);
            end else
                if AssignmentType = AssignmentType::Purchase then begin
                    ItemChargeAssgntPurch."Unit Cost" := UnitCost;
                    AssignItemChargePurch.CreateReturnRcptChargeAssgnt(FromReturnRcptLine, ItemChargeAssgntPurch);
                end;
    end;

    procedure GetShipmentLine(DocNo: Code[20]; LineNo: Integer; UnitCost: Decimal; AssignmentType1: text; ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)"; ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)")
    var
        FromSalesShptLine: Record "Sales Shipment Line";
        AssignmentType: Option Sale,Purchase;
        //ItemChargeAssgntSales: Record "Item Charge Assignment (Sales)";
        AssignItemChargeSales: Codeunit "Item Charge Assgnt. (Sales)";
        //ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
    begin
        Case AssignmentType1 of
            'Sale':
                AssignmentType := AssignmentType::Sale;
            'Purchase':
                AssignmentType := AssignmentType::Purchase;
        end;
        FromSalesShptLine.Reset();
        FromSalesShptLine.SetRange("Document No.", DocNo);
        FromSalesShptLine.SetRange("Line No.", LineNo);
        //CurrPage.SetSelectionFilter(FromSalesShptLine);
        if FromSalesShptLine.FindFirst() then
            if AssignmentType = AssignmentType::Sale then begin
                ItemChargeAssgntSales."Unit Cost" := UnitCost;
                AssignItemChargeSales.CreateShptChargeAssgnt(FromSalesShptLine, ItemChargeAssgntSales);
            end else
                if AssignmentType = AssignmentType::Purchase then begin
                    ItemChargeAssgntPurch."Unit Cost" := UnitCost;
                    AssignItemChargePurch.CreateSalesShptChargeAssgnt(FromSalesShptLine, ItemChargeAssgntPurch);
                end;
    end;

    procedure GetTransferReceiptLine(DocNo: Code[20]; LineNo: Integer; UnitCost: Decimal; ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)")
    Var
        //ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
        FromTransRcptLine: Record "Transfer Receipt Line";
        CreateCostDistrib: Boolean;
    begin
        if CreateCostDistrib then begin
            FromTransRcptLine.Reset();
            FromTransRcptLine.SetRange("Document No.", DocNo);
            FromTransRcptLine.SetRange("Line No.", LineNo);
            //CurrPage.SetSelectionFilter(FromTransRcptLine);
            if FromTransRcptLine.FindFirst() then begin
                ItemChargeAssgntPurch."Unit Cost" := UnitCost;
                AssignItemChargePurch.CreateTransferRcptChargeAssgnt(FromTransRcptLine, ItemChargeAssgntPurch);
            end;
        end;
    end;

    procedure GetReturnShipmentLine(DocNo: Code[20]; LineNo: Integer; UnitCost: Decimal; ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)")
    var
        FromReturnShptLine: Record "Return Shipment Line";
        //ItemChargeAssgntPurch: Record "Item Charge Assignment (Purch)";
        AssignItemChargePurch: Codeunit "Item Charge Assgnt. (Purch.)";
    begin
        FromReturnShptLine.Reset();
        FromReturnShptLine.SetRange("Document No.", DocNo);
        FromReturnShptLine.SetRange("Line No.", LineNo);
        //CurrPage.SetSelectionFilter(FromReturnShptLine);
        if FromReturnShptLine.FindFirst() then begin
            ItemChargeAssgntPurch."Unit Cost" := UnitCost;
            AssignItemChargePurch.CreateShptChargeAssgnt(FromReturnShptLine, ItemChargeAssgntPurch);
        end;
    end;

    [ServiceEnabled]
    procedure SetVendApplId(PONo: Code[20]; VendLedEntry: Integer; CurrentRec: Boolean)
    var
        VendLedger: Record "Vendor Ledger Entry";

    begin
        PurchHeader.Reset();
        PurchHeader.SetRange("No.", PONo);
        if PurchHeader.FindFirst() then;
        PurchHeader."Applies-to ID" := PurchHeader."No.";
        VendLedger.Reset();
        VendLedger.SetRange("Entry No.", VendLedEntry);
        if VendLedger.FindFirst() then;
        CheckVendLedgEntry(VendLedger);
        //OnSetVendApplIdOnAfterCheckAgainstApplnCurrency(Rec, CalcType.AsInteger(), GenJnlLine, PurchHeader, TempApplyingVendLedgEntry);

        VendLedgEntry.Copy(VendLedger);
        // if CurrentRec then
        //     VendLedgEntry.SetRecFilter()
        // else
        //     CurrPage.SetSelectionFilter(VendLedgEntry);

        //OnSetVendApplIdOnAfterSetFilter(Rec, CurrentRec, VendLedgEntry, TempApplyingVendLedgEntry);

        CallVendEntrySetApplIDSetApplId();
        PurchHeader."Applies-to Doc. No." := '';
        PurchHeader."Applies-to Doc. Type" := PurchHeader."Applies-to Doc. Type"::" ";
        PurchHeader.Modify();
        //CalcApplnAmount();
    end;



    local procedure CallVendEntrySetApplIDSetApplId()
    var
        IsHandled: Boolean;
        VendEntrySetApplID: Codeunit "Vend. Entry-SetAppl.ID";
    begin
        // IsHandled := false;
        // OnBeforeCallVendEntrySetApplIDSetApplId(VendEntrySetApplID, VendLedgEntry, TempApplyingVendLedgEntry, IsHandled);
        // if IsHandled then
        //     exit;

        if GenJnlLineApply then
            VendEntrySetApplID.SetApplId(VendLedgEntry, TempApplyingVendLedgEntry, GenJnlLine."Applies-to ID")
        else
            VendEntrySetApplID.SetApplId(VendLedgEntry, TempApplyingVendLedgEntry, PurchHeader."Applies-to ID");
    end;

    procedure CheckVendLedgEntry(var VendorLedgerEntry: Record "Vendor Ledger Entry")
    var
        RaiseError: Boolean;
        CalcType: Enum "Vendor Apply Calculation Type";

        ApplnCurrencyCode: Code[10];
        GenJnlApply: Codeunit "Gen. Jnl.-Apply";

        EarlierPostingDateErr: Label 'You cannot apply and post an entry to an entry with an earlier posting date.\\Instead, post the document of type %1 with the number %2 and then apply it to the document of type %3 with the number %4.', Comment = '%1 - document type, %2 - document number,%3 - document type,%4 - document number';
    begin
        if VendorLedgerEntry.FindSet() then
            repeat
                if CalcType = CalcType::"Gen. Jnl. Line" then begin
                    RaiseError := TempApplyingVendLedgEntry."Posting Date" < VendorLedgerEntry."Posting Date";
                    // OnBeforeEarlierPostingDateError(
                    //     TempApplyingVendLedgEntry, VendorLedgerEntry, RaiseError, CalcType.AsInteger(), PmtDiscAmount);
                    if RaiseError then
                        Error(
                            EarlierPostingDateErr, TempApplyingVendLedgEntry."Document Type", TempApplyingVendLedgEntry."Document No.",
                            VendorLedgerEntry."Document Type", VendorLedgerEntry."Document No.");

                    //OnCheckVendLedgEntryOnAfterEarlierPostingDateTest(TempApplyingVendLedgEntry, VendorLedgerEntry, CalcType, OK);
                end;

                if TempApplyingVendLedgEntry."Entry No." <> 0 then begin
                    //OnCheckVendLedgEntryOnBeforeCheckAgainstApplnCurrency(GenJnlLine, VendorLedgerEntry);
                    GenJnlApply.CheckAgainstApplnCurrency(
                        ApplnCurrencyCode, VendorLedgerEntry."Currency Code", GenJnlLine."Account Type"::Vendor, true);
                end;
            until VendorLedgerEntry.Next() = 0;
    end;

    [ServiceEnabled]
    procedure GetItemMovementSummary(StartDate: Date; EndDate: Date): Text
    var
        SqlConn: DotNet SqlConnection;
        SqlCmd: DotNet SqlCommand;
        SqlReader: DotNet SqlDataReader;
        ConnString: Text;
        JsonText: Text;
        JsonArray: JsonArray;
        JsonObject: JsonObject;
        Base64Conv: Codeunit "Base64 Convert";
    begin
        ConnString := 'Server=10.10.32.204,1433;Database=BC23;Integrated Security=True;TrustServerCertificate=True;';
        SqlConn := SqlConn.SqlConnection(ConnString);
        SqlConn.Open();

        SqlCmd := SqlCmd.SqlCommand('dbo.ItemMovementSummary', SqlConn);
        SqlCmd.CommandType := SqlCmd.CommandType.StoredProcedure;
        SqlCmd.Parameters.AddWithValue('@StartDate', StartDate);
        SqlCmd.Parameters.AddWithValue('@EndDate', EndDate);

        SqlReader := SqlCmd.ExecuteReader();

        // JsonArray := JsonArray.Create();

        while SqlReader.Read() do begin
            Clear(JsonObject);
            JsonObject.Add('ItemNo', SqlReader.GetString(0));
            JsonObject.Add('Description', SqlReader.GetString(1));
            JsonObject.Add('BaseUoM', SqlReader.GetString(2));
            JsonObject.Add('OpeningQty', Format(SqlReader.GetDecimal(3)));
            JsonObject.Add('OpeningValue', Format(SqlReader.GetDecimal(4)));
            JsonObject.Add('IncreasesQty', Format(SqlReader.GetDecimal(5)));
            JsonObject.Add('IncreasesValue', Format(SqlReader.GetDecimal(6)));
            JsonObject.Add('DecreasesQty', Format(SqlReader.GetDecimal(7)));
            JsonObject.Add('DecreasesValue', Format(SqlReader.GetDecimal(8)));
            JsonObject.Add('ClosingQty', Format(SqlReader.GetDecimal(9)));
            JsonObject.Add('ClosingValue', Format(SqlReader.GetDecimal(10)));
            JsonArray.Add(JsonObject);
        end;

        SqlReader.Close();
        SqlConn.Close();

        JsonArray.WriteTo(JsonText);

        exit(Base64Conv.ToBase64(JsonText));
    end;

    [ServiceEnabled]
    procedure GetPendingMRNExcel(Branch: Code[100]; sfpluserID: Text[20]): Text
    var
        TempExcelBuffer: Record "Excel Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        OutStr: OutStream;
        InStr: InStream;
        Base64: Codeunit "Base64 Convert";
        PurchRcptLine: Record "Purch. Rcpt. Line";
        Vendor: Record Vendor;
        Location: Record Location;
        RespCenterList: List of [Text];
        RespTxt: Text;
    begin
        // Create new Excel sheet
        TempExcelBuffer.CreateNewBook('Pending MRN');
        TempExcelBuffer.WriteSheet('Pending MRN', CompanyName, sfpluserID);

        ReportName[1] := 'Report Name :';
        ReportName[2] := 'Pending MRN Report';
        for I := 1 to 5 do begin
            if I = 2 then begin
                ReportName[1] := 'Report Filters :';
                ReportName[2] := Branch
            end else if I = 3 then begin
                ReportName[1] := 'WorkDate :';
                ReportName[2] := Format(Today);
            end else if I = 4 then begin
                ReportName[1] := 'USER :';
                ReportName[2] := SFPLUserID;
            end;

            if I <> 5 then begin
                TempExcelBuffer.NewRow;
                TempExcelBuffer.AddColumn(ReportName[1], FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn(ReportName[2], FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
            END ELSE BEGIN
                TempExcelBuffer.NewRow;
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', TempExcelBuffer."Cell Type"::Text);//GK
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', TempExcelBuffer."Cell Type"::Text);
                TempExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ReportName[1] := '';
                ReportName[2] := '';
            END;
        end;
        // Add header row
        TempExcelBuffer.NewRow();
        TempExcelBuffer.AddColumn('LOB Code', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Location Code', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Location Name', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Posting Date', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Document No.', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Vendor Name', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Description', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Quantity', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Qty Invoiced', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);
        TempExcelBuffer.AddColumn('Qty Recvd Not Invoiced', false, '', true, false, true, '', TempExcelBuffer."Cell Type"::Text);

        RespTxt := Branch;
        RespCenterList := RespTxt.Split('|');

        PurchRcptLine.Reset();
        //PurchRcptLine.SetRange("Shortcut Dimension 2 Code", Branch);
        PurchRcptLine.SetFilter("Qty. Rcd. Not Invoiced", '<>%1', 0);
        PurchRcptLine.SetFilter(Type, '<>%1', PurchRcptLine.Type::" ");
        if PurchRcptLine.FindSet() then
            repeat
                if (RespCenterList.Contains(PurchRcptLine."Shortcut Dimension 2 Code")) or (Branch = '') then begin
                    TempExcelBuffer.NewRow();
                    TempExcelBuffer.AddColumn(PurchRcptLine."Shortcut Dimension 1 Code", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine."Location Code", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    Location.Get(PurchRcptLine."Location Code");
                    TempExcelBuffer.AddColumn(Location.Name, false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine."Posting Date", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine."Document No.", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    if Vendor.Get(PurchRcptLine."Buy-from Vendor No.") then
                        TempExcelBuffer.AddColumn(Vendor.Name, false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text)
                    else
                        TempExcelBuffer.AddColumn('', false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);

                    TempExcelBuffer.AddColumn(PurchRcptLine.Description, false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine.Quantity, false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine."Quantity Invoiced", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                    TempExcelBuffer.AddColumn(PurchRcptLine."Qty. Rcd. Not Invoiced", false, '', false, false, true, '', TempExcelBuffer."Cell Type"::Text);
                end;
            until PurchRcptLine.Next() = 0;

        // Save Excel to stream
        TempBlob.CreateOutStream(OutStr);
        TempExcelBuffer.CreateNewBook('Pending MRN');
        TempExcelBuffer.WriteSheet('Pending MRN Report', CompanyName, SFPLUserID);
        TempExcelBuffer.CloseBook();
        TempExcelBuffer.SaveToStream(OutStr, true);
        TempBlob.CreateInStream(InStr);
        exit(Base64.ToBase64(InStr));
    end;

    [ServiceEnabled]
    procedure ExportItemAvailabilityExcel(PEndDate: Date; PLocationCode: Code[20]; PItemNo: Code[50]; Branch: Code[100]; SFPLUserID: text[20]): Text
    var
        Item: Record Item;
        Location: Record Location;
        TempDataIL: Record "Item Loc Inventory Temp" temporary;
        TempDataVE: Record "Item Loc Inventory Temp" temporary;
        ValueEntryQuery: Query "ValueEntr by Item-Location";
        ItemLocationQuery: Query "Item Location Inventory";
        ExcelBuffer: Record "Excel Buffer" temporary;
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
        InStream: InStream;
        Base64Conv: Codeunit "Base64 Convert";
        RespCenterList: List of [Text];
        RespTxt: Text;
        I: Integer;
        ReportName: array[10] of Text;
    begin
        // Apply filters to queries
        if PLocationCode <> '' then begin
            ValueEntryQuery.SetFilter(ValueEntryQuery.LocationCode, PLocationCode);
            ItemLocationQuery.SetFilter(ItemLocationQuery.LocationCode, PLocationCode);
        end;
        if PItemNo <> '' then begin
            ValueEntryQuery.SetFilter(ValueEntryQuery.ItemNo, PItemNo);
            ItemLocationQuery.SetFilter(ItemLocationQuery.ItemNo, PItemNo);
        end;
        if PEndDate <> 0D then begin
            ValueEntryQuery.SetFilter(ValueEntryQuery.Posting_Date, '..%1', PEndDate);
            ItemLocationQuery.SetFilter(ItemLocationQuery.Posting_Date, '..%1', PEndDate);
        end;

        // Collect cost amounts
        ValueEntryQuery.Open();
        while ValueEntryQuery.Read() do begin
            if not TempDataVE.Get(ValueEntryQuery.ItemNo, ValueEntryQuery.LocationCode) then begin
                TempDataVE.Init();
                TempDataVE."Item No." := ValueEntryQuery.ItemNo;
                TempDataVE."Location Code" := ValueEntryQuery.LocationCode;
                TempDataVE."Cost Amount (Actual)" := ValueEntryQuery.CostAmount;
                TempDataVE.Insert();
            end else begin
                TempDataVE."Cost Amount (Actual)" += ValueEntryQuery.CostAmount;
                TempDataVE.Modify();
            end;
        end;

        // Responsibility center filter
        RespTxt := Branch;
        RespCenterList := RespTxt.Split('|');

        // Collect inventory and item details
        ItemLocationQuery.Open();
        while ItemLocationQuery.Read() do begin
            if Item.Get(ItemLocationQuery.ItemNo) and Location.Get(ItemLocationQuery.LocationCode) then
                if Item.Type = Item.Type::Inventory then
                    if (RespCenterList.Contains(Location."Global Dimension 2 Code")) or (Branch = '') then begin
                        if not TempDataIL.Get(ItemLocationQuery.ItemNo, ItemLocationQuery.LocationCode) then begin
                            TempDataIL.Init();
                            TempDataIL."Item No." := ItemLocationQuery.ItemNo;
                            TempDataIL."Location Code" := ItemLocationQuery.LocationCode;
                            TempDataIL.Inventory := ItemLocationQuery.Inventory;
                            TempDataVE.Reset();
                            if TempDataVE.Get(ItemLocationQuery.ItemNo, ItemLocationQuery.LocationCode) then
                                TempDataIL."Cost Amount (Actual)" := TempDataVE."Cost Amount (Actual)"
                            else
                                TempDataIL."Cost Amount (Actual)" := 0; // already aggregated
                            TempDataIL."Item Description" := Item.Description;
                            TempDataIL."Item UOM" := Item."Base Unit of Measure";
                            TempDataIL."Location Name" := Location.Name;
                            TempDataIL."Inventory Posting Group" := Item."Inventory Posting Group";
                            TempDataIL."Responsibilty Center" := Location."Responsibility Center";
                            TempDataIL.Branch := Location."Global Dimension 2 Code";
                            TempDataIL.Insert();
                        end else begin
                            TempDataIL.Inventory += ItemLocationQuery.Inventory;
                            TempDataIL.Modify();
                        end;
                    end;
        end;

        // Remove zero inventory
        TempDataIL.Reset();
        TempDataIL.SetRange(Inventory, 0);
        TempDataIL.DeleteAll();

        ReportName[1] := 'Report Name :';
        ReportName[2] := 'Item Availability';
        for I := 1 to 5 do begin
            if I = 2 then begin
                ReportName[1] := 'Report Filters :';
                ReportName[2] := Format(PEndDate) + '|' + Branch
            end else if I = 3 then begin
                ReportName[1] := 'WorkDate :';
                ReportName[2] := Format(Today);
            end else if I = 4 then begin
                ReportName[1] := 'USER :';
                ReportName[2] := SFPLUserID;
            end;

            if I <> 5 then begin
                ExcelBuffer.NewRow;
                ExcelBuffer.AddColumn(ReportName[1], FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(ReportName[2], FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
            END ELSE BEGIN
                ExcelBuffer.NewRow;
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, TRUE, '', ExcelBuffer."Cell Type"::Text);//GK
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn('', FALSE, '', TRUE, FALSE, FALSE, '', ExcelBuffer."Cell Type"::Text);
                ReportName[1] := '';
                ReportName[2] := '';
            END;
        end;
        ExcelBuffer.NewRow();
        ExcelBuffer.AddColumn('Location Code', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Location Name', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Inventory Posting Group', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Branch', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Item No.', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Item Description', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('UOM', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Text);
        ExcelBuffer.AddColumn('Inventory', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Number);
        ExcelBuffer.AddColumn('Cost Amount (Actual)', false, '', true, false, true, '', ExcelBuffer."Cell Type"::Number);

        TempDataIL.reset;
        if TempDataIL.FindSet() then
            repeat
                ExcelBuffer.NewRow();

                ExcelBuffer.AddColumn(TempDataIL."Location Code", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL."Location Name", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL."Inventory Posting Group", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL.Branch, false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL."Item No.", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL."Item Description", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(TempDataIL."Item UOM", false, '', false, false, true, '', ExcelBuffer."Cell Type"::Text);
                ExcelBuffer.AddColumn(Format(TempDataIL.Inventory), false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
                ExcelBuffer.AddColumn(Format(TempDataIL."Cost Amount (Actual)"), false, '', false, false, true, '', ExcelBuffer."Cell Type"::Number);
            until TempDataIL.Next() = 0;

        // Export to Base64
        TempBlob.CreateOutStream(OutStream);
        ExcelBuffer.CreateNewBook('Item Availability');
        ExcelBuffer.WriteSheet('Item Availability', CompanyName, SFPLUserID);
        ExcelBuffer.CloseBook();
        ExcelBuffer.SaveToStream(OutStream, true);
        TempBlob.CreateInStream(InStream);
        exit(Base64Conv.ToBase64(InStream));
    end;




    var
        COdeUnit50031: Codeunit BaseModificationCodeunitt;
        PurchRcptLine: Record "Purch. Rcpt. Line";
        TempWhseJnlLine: Record "Warehouse Journal Line" temporary;
        TempGlobalItemLedgEntry: Record "Item Ledger Entry" temporary;
        UndoPostingMgt: Codeunit "Undo Posting Management";

        Text000: Label '%1 journal';
        Text003: Label 'DEFAULT';
        Text004: Label 'Production Journal';
        Text005: Label '%1 %2 for operation %3 is blocked and therefore, no journal line is created for this operation.';
        GeneratingJnlLinesMsg: Label 'Generating journal lines.';
        BlockedMsg: Label '%2 %1 is blocked and therefore, no journal line is created for this %2.', Comment = '%1 - Entity No, %2 - Table caption';
        Text010: Label 'One or more reservation entries exist for the item with %1 = %2, %3 = %4, %5 = %6 which may be disrupted if you post this negative adjustment. Do you want to continue?', Comment = 'One or more reservation entries exist for the item with Item No. = 1000, Location Code = BLUE, Variant Code = NEW which may be disrupted if you post this negative adjustment. Do you want to continue?';
        ItemSubstitution: Record "Item Substitution";
        ItemSubstitution2: Record "Item Substitution";
        UOMMgt: Codeunit "Unit of Measure Management";
        TempApplyingVendLedgEntry: Record "Vendor Ledger Entry" temporary;
        VendLedgEntry: Record "Vendor Ledger Entry";
        GenJnlLine: Record "Gen. Journal Line";
        PurchHeader: Record "Purchase Header";
        GenJnlLineApply: Boolean;
        ODF: DateFormula;
        RelationsLevel2: Integer;
        Item: Record Item;
        TempItemSubstitution: Record "Item Substitution" temporary;
        AvailToPromise: Codeunit "Available to Promise";
        MfgSetup: Record "Manufacturing Setup";
        ItemJnlLine: Record "Item Journal Line";
        ItemJnlTemplate: Record "Item Journal Template";
        ItemJnlBatch: Record "Item Journal Batch";
        ToTemplateName: Code[10];
        ToBatchName: Code[10];
        NextLineNo: Integer;
        PostingDate: Date;
        CalcBasedOn: Option "Actual Output","Expected Output";
        PresetOutputQuantity: Option "Expected Quantity","Zero on All Operations","Zero on Last Operation";
        prodJnMgt: Codeunit "Production Journal Mgt";
        RecordLink: Record "Record Link";


procedure RemoveDuplicateGSTLedgerEntries(DocumentNoFilter: Code[20]; IsPreviewMode: Boolean): Integer
    var
        DetailedGSTLedgerEntry: Record "Detailed GST Ledger Entry";
        LastDocumentNo: Code[20];
        LastDocumentLineNo: Integer;
        LastGSTComponentCode: Code[10];
        DeletedCount: Integer;
    begin
        DetailedGSTLedgerEntry.Reset();

        // Apply Document No. filter if provided
        if DocumentNoFilter <> '' then
            DetailedGSTLedgerEntry.SetRange("Document No.", DocumentNoFilter);

        // Sort by Document No., Line No., GST Component Code, and Entry No. (Ascending)
        DetailedGSTLedgerEntry.SetCurrentKey("Document No.", "Document Line No.", "GST Component Code", "Entry No.");
        DetailedGSTLedgerEntry.Ascending(true);

        if DetailedGSTLedgerEntry.FindSet() then
            repeat
                // Check if current record matches the previous unique key combination
                if (DetailedGSTLedgerEntry."Document No." = LastDocumentNo) and
                   (DetailedGSTLedgerEntry."Document Line No." = LastDocumentLineNo) and
                   (DetailedGSTLedgerEntry."GST Component Code" = LastGSTComponentCode) then begin
                    
                    // Duplicate found: Skip first record, delete subsequent duplicate records
                    if not IsPreviewMode then
                        DetailedGSTLedgerEntry.Delete(false);

                    DeletedCount += 1;
                end else begin
                    // First occurrence: Store key details and keep the record
                    LastDocumentNo := DetailedGSTLedgerEntry."Document No.";
                    LastDocumentLineNo := DetailedGSTLedgerEntry."Document Line No.";
                    LastGSTComponentCode := DetailedGSTLedgerEntry."GST Component Code";
                end;
            until DetailedGSTLedgerEntry.Next() = 0;

        exit(DeletedCount);
    end;

}

