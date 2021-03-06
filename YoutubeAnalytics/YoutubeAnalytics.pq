﻿section YoutubeAnalytics;

appKey="163337191747-llpbu679m7h93vjgsrnsta6934rjprou.apps.googleusercontent.com";
appSecret="ivBGONHdPKstgsdNcOy6LAzl";
redirectUrl = "https://oauth.powerbi.com/views/oauthredirect.html";
token_uri = "https://accounts.google.com/o/oauth2/token";
authorize_uri = "https://accounts.google.com/o/oauth2/auth";
logout_uri = "https://accounts.google.com/logout";
channel_id = "UCy_OwhQ_foCbaSKhMhuvgRw";

windowWidth = 720;
windowHeight = 1024;

// See https://developers.google.com/identity/protocols/googlescopes for scopes 
scope_prefix = "https://www.googleapis.com/auth/";
scopes = {
"yt-analytics-monetary.readonly", 
"yt-analytics.readonly",  
"youtube.readonly"
};

Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each prefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

[DataSource.Kind="YoutubeAnalytics", Publish="YoutubeAnalytics.Publish"]

shared YoutubeAnalytics.Navigation = () =>
    let
        objects = #table(
            {"Name",       "Key",        "Data",                           "ItemKind", "ItemName", "IsLeaf"},{
            {"Channel",      "YoutubeAnalytics.ChannelInfo",      YoutubeAnalytics.ChannelInfo(), "Table",    "Table",    true},
            {"Videos",      "YoutubeAnalytics.Videos",      YoutubeAnalytics.Videos(), "Table",    "Table",    true},
            {"Countries",      "YoutubeAnalytics.Countries",      YoutubeAnalytics.Countries(), "Table",    "Table",    true},            
            {"Video Stats", "YoutubeAnalytics.VideoStats", YoutubeAnalytics.VideoStats(),       "Function", "Function", true},
            {"Daily Subscribers", "YoutubeAnalytics.DailySubscribers", YoutubeAnalytics.DailySubscribers(),       "Function", "Function", true}
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;
 
 [DataSource.Kind="YoutubeAnalytics"]
shared YoutubeAnalytics.ChannelInfo = () as table =>
   
let
    Source = Web.Contents("https://www.googleapis.com/youtube/v3/channels?id=" & channel_id &"&part=snippet,statistics"),
    #"Imported JSON" = Json.Document(Source),
    items = #"Imported JSON"[items],
    #"Converted to Table" = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"kind", "etag", "id", "snippet", "statistics"}, {"kind", "etag", "id", "snippet", "statistics"}),
    #"Removed Columns" = Table.RemoveColumns(#"Expanded Column1",{"kind", "etag", "id"}),
    #"Expanded snippet" = Table.ExpandRecordColumn(#"Removed Columns", "snippet", {"title", "description", "customUrl", "publishedAt", "thumbnails", "localized", "country"}, {"title", "description", "customUrl", "publishedAt", "thumbnails", "localized", "country"}),
    #"Renamed Columns" = Table.RenameColumns(#"Expanded snippet",{{"title", "Channel Name"}, {"description", "Channel Description"}}),
    #"Expanded thumbnails" = Table.ExpandRecordColumn(#"Renamed Columns", "thumbnails", {"default", "medium", "high"}, {"default", "medium", "high"}),
    #"Removed Columns1" = Table.RemoveColumns(#"Expanded thumbnails",{"localized"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Removed Columns1",{{"country", "Country"}}),
    #"Expanded default" = Table.ExpandRecordColumn(#"Renamed Columns1", "default", {"url"}, {"url"}),
    #"Renamed Columns2" = Table.RenameColumns(#"Expanded default",{{"url", "Default Channel Avatar"}}),
    #"Expanded medium" = Table.ExpandRecordColumn(#"Renamed Columns2", "medium", {"url"}, {"url"}),
    #"Renamed Columns3" = Table.RenameColumns(#"Expanded medium",{{"url", "Medium Channel Avatar"}}),
    #"Expanded high" = Table.ExpandRecordColumn(#"Renamed Columns3", "high", {"url"}, {"url"}),
    #"Renamed Columns4" = Table.RenameColumns(#"Expanded high",{{"url", "HighChannel Avatar"}}),
    #"Changed Type" = Table.TransformColumnTypes(#"Renamed Columns4",{{"HighChannel Avatar", type text}, {"Medium Channel Avatar", type text}, {"Default Channel Avatar", type text}, {"customUrl", type text}, {"Channel Description", type text}, {"Channel Name", type text}, {"publishedAt", type datetimezone}}),
    #"Added Custom" = Table.AddColumn(#"Changed Type", "Custom Channel url", each "https://www.youtube.com/"&[customUrl]),
    #"Changed Type1" = Table.TransformColumnTypes(#"Added Custom",{{"Custom Channel url", type text}}),
    #"Removed Columns2" = Table.RemoveColumns(#"Changed Type1",{"customUrl"}),
    #"Expanded statistics" = Table.ExpandRecordColumn(#"Removed Columns2", "statistics", {"viewCount", "subscriberCount", "videoCount"}, {"viewCount", "subscriberCount", "videoCount"}),
    #"Changed Type2" = Table.TransformColumnTypes(#"Expanded statistics",{{"viewCount", Int64.Type}, {"subscriberCount", Int64.Type}, {"videoCount", Int64.Type}})
in
    #"Changed Type2";

[DataSource.Kind="YoutubeAnalytics"]
shared YoutubeAnalytics.VideoStats = ( optional StartDate as date, optional EndDate as date)  =>
  let
      Start = Date.ToText ( StartDate, "yyyy-MM-dd"),
      End =  Date.ToText ( EndDate, "yyyy-MM-dd"),
     videos = Text.Combine(List.Transform(YoutubeAnalytics.Videos()[videoId], Text.From), "%2C"),
    #"Added Custom" =  Table.AddColumn(Table.TransformColumns(Table.SelectColumns(YoutubeAnalytics.Countries(),{"Country code"}),{},Text.Lower) , "Response", 
             each Json.Document(
                     Web.Contents("https://www.googleapis.com/youtube/analytics/v1/reports?ids=channel%3D%3D"&channel_id&"&start-date="&Start&"&end-date="& End &"&metrics=views%2Clikes%2Cdislikes%2Cshares%2CestimatedRevenue%2Ccomments%2CaverageViewDuration%2CestimatedMinutesWatched%2CadImpressions%2Ccpm%2CaverageViewPercentage%2CsubscribersGained%2CsubscribersLost&dimensions=day%2Cvideo&filters=video%3D%3D"&videos&"%3Bcountry%3D%3D"&[Country code]))),
///Information about the metrics that are used https://developers.google.com/youtube/analytics/v1/dimsmets/mets#viewerPercentage
#"Expanded Custom.1" = Table.ExpandRecordColumn(#"Added Custom", "Response", {"rows"}, {"rows"}),
    #"Filtered Rows1" = Table.SelectRows(#"Expanded Custom.1", each [rows] <> null),
    #"Expanded rows" = Table.ExpandListColumn(#"Filtered Rows1", "rows"),
    #"Added Custom2" = Table.AddColumn(#"Expanded rows", "Custom", each Table.Transpose(Table.FromList([rows], Splitter.SplitByNothing()))),
    #"Removed Columns2" = Table.RemoveColumns(#"Added Custom2",{"rows"}),
    #"Expanded Custom" = Table.ExpandTableColumn(#"Removed Columns2", "Custom", {"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8","Column9","Column10","Column11","Column12","Column13","Column14","Column15"}, {"Column1", "Column2", "Column3", "Column4", "Column5", "Column6", "Column7", "Column8","Column9","Column10","Column11","Column12","Column13","Column14","Column15"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Expanded Custom",{{"Column1", "Date"}, {"Column2", "VideoID"}, {"Column3", "Views"}, {"Column4", "Likes"}, {"Column5", "Dislikes"}, {"Column6", "Shares"}, {"Column7", "estimatedRevenue"}, {"Column8", "comments"},{"Column9", "averageViewDuration"},{"Column10", "estimatedMinutesWatched"},{"Column11", "adImpressions"},{"Column12", "cpm"},{"Column13", "averageViewPercentage"},{"Column14", "subscribersGained"},{"Column15", "subscribersLost"}}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Renamed Columns1",{{"comments", Int64.Type}, {"Shares", Int64.Type}, {"Dislikes", Int64.Type}, {"Likes", Int64.Type}, {"Views", Int64.Type}, {"estimatedRevenue", type number}, {"VideoID", type text}, {"Date", type date},{"averageViewDuration", type number},{"estimatedMinutesWatched", type number},{"adImpressions", type number},{"cpm", type number},{"averageViewPercentage", type number},{"subscribersGained", type number},{"subscribersLost", type number}}),
    result = if StartDate = null  and EndDate =null then Error.Record("Parameters Issue", "StartDate and EndDate can not be null", "StartDate = null & EndDate = null") else 
           if StartDate = null then Error.Record("Parameters Issue", "StartDate can not be null", "StartDate = null") else 
           if EndDate = null then Error.Record("Parameters Issue", "EndDate can not be null", "EndDate = null") else
           if Number.From(StartDate) > Number.From(EndDate) then Error.Record("Parameters Issue","StartDate can't be after EndDate", "StartDate > EndDate") else #"Changed Type1"
in
    result;

[DataSource.Kind="YoutubeAnalytics"]
shared YoutubeAnalytics.DailySubscribers = (optional StartDate as date, optional EndDate as date) =>
 ///*****Data for "Subscribers lost" and "Subscribers" is not correctly tracked between August 20, 2013 and August 23, 2013
 ////*****Data for "Subscribers gained", "Subscribers lost", and "Subscribers" is not correctly tracked between January 13, 2015 and January 15, 2015.
  let
      Start = Date.ToText ( StartDate, "yyyy-MM-dd"),
      End =  Date.ToText ( EndDate, "yyyy-MM-dd"),
    #"Added Custom" =  Table.AddColumn(Table.TransformColumns(Table.SelectColumns(YoutubeAnalytics.Countries(),{"Country code"}),{},Text.Lower) , "Response", 
             each Json.Document(
                     Web.Contents("https://www.googleapis.com/youtube/analytics/v1/reports?ids=channel%3D%3D"&channel_id&"&start-date="&Start&"&end-date="& End &"&metrics=subscribersGained%2CsubscribersLost&dimensions=day&filters=country%3D%3D"&[Country code]))),
///Information about the metrics that are used https://developers.google.com/youtube/analytics/v1/dimsmets/mets
#"Expanded Custom.1" = Table.ExpandRecordColumn(#"Added Custom", "Response", {"rows"}, {"rows"}),
    #"Filtered Rows1" = Table.SelectRows(#"Expanded Custom.1", each [rows] <> null),
    #"Expanded rows" = Table.ExpandListColumn(#"Filtered Rows1", "rows"),
    #"Added Custom2" = Table.AddColumn(#"Expanded rows", "Custom", each Table.Transpose(Table.FromList([rows], Splitter.SplitByNothing()))),
    #"Removed Columns2" = Table.RemoveColumns(#"Added Custom2",{"rows"}),
    #"Expanded Custom" = Table.ExpandTableColumn(#"Removed Columns2", "Custom", {"Column1", "Column2", "Column3"}, {"Column1", "Column2", "Column3"}),
    #"Renamed Columns1" = Table.RenameColumns(#"Expanded Custom",{{"Column1", "Date"}, {"Column2", "subscribersGained"}, {"Column3", "subscribersLost"}}),
    #"Changed Type1" = Table.TransformColumnTypes(#"Renamed Columns1",{{"Date", type date},{"subscribersGained", type number},{"subscribersLost", type number}}),
    result = if StartDate = null  and EndDate =null then Error.Record("Parameters Issue", "StartDate and EndDate can not be null", "StartDate = null & EndDate = null") else 
           if StartDate = null then Error.Record("Parameters Issue", "StartDate can not be null", "StartDate = null") else 
           if EndDate = null then Error.Record("Parameters Issue", "EndDate can not be null", "EndDate = null") else
           if Number.From(StartDate) > Number.From(EndDate) then Error.Record("Parameters Issue","StartDate can't be after EndDate", "StartDate > EndDate") else #"Changed Type1"

in
    result;


[DataSource.Kind="YoutubeAnalytics"]
shared YoutubeAnalytics.Countries = () as table =>
 let
    Source= Table.FromRows(Json.Document(Binary.Decompress(Binary.FromText("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", BinaryEncoding.Base64), Compression.Deflate)), let _t = ((type text) meta [Serialized.Text = true]) in type table [Country = _t, #"Country code" = _t]),
    #"Changed Type" = Table.TransformColumnTypes(Source,{{"Country", type text}, {"Country code", type text}})
in
    #"Changed Type";
    
[DataSource.Kind="YoutubeAnalytics"]
shared YoutubeAnalytics.Videos = () as table =>
let
    Source = Web.Contents("https://www.googleapis.com/youtube/v3/search?channelId="& channel_id &"&part=snippet,id&order=date&maxResults=50"),
    #"Imported JSON" = Json.Document(Source),
    items = #"Imported JSON"[items],
    #"Converted to Table" = Table.FromList(items, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"kind", "etag", "id", "snippet"}, {"kind", "etag", "id", "snippet"}),
    #"Expanded id" = Table.ExpandRecordColumn(#"Expanded Column1", "id", {"videoId"}, {"videoId"}),
    #"Expanded snippet" = Table.ExpandRecordColumn(#"Expanded id", "snippet", {"publishedAt", "title", "description", "thumbnails", "liveBroadcastContent"}, {"publishedAt", "title", "description", "thumbnails", "liveBroadcastContent"}),
    #"Se expandió thumbnails" = Table.ExpandRecordColumn(#"Expanded snippet", "thumbnails", {"default", "medium", "high"}, {"default", "medium", "high"}),
    #"Se expandió high" = Table.ExpandRecordColumn(#"Se expandió thumbnails", "high", {"url"}, {"url"}),
    #"Expanded default" = Table.ExpandRecordColumn(#"Se expandió high", "default", {"url"}, {"url.1"}),
    #"Expanded medium" = Table.ExpandRecordColumn(#"Expanded default", "medium", {"url"}, {"url.2"}),
    #"Renamed Columns" = Table.RenameColumns(#"Expanded medium",{{"url.1", "Default Thumbnail"}, {"url.2", "Medium Thumbnail"}, {"url", "High Thumbnail"}}),
    #"Filtered Rows" = Table.SelectRows(#"Renamed Columns", each ([videoId] <> null)),
    #"Removed Columns" = Table.RemoveColumns(#"Filtered Rows",{"kind", "etag"}),
    #"Changed Type" = Table.TransformColumnTypes(#"Removed Columns",{{"videoId", type text}, {"title", type text}, {"description", type text}, {"Default Thumbnail", type text}, {"Medium Thumbnail", type text}, {"High Thumbnail", type text}, {"liveBroadcastContent", type text}, {"publishedAt", type datetimezone}})
    in 
        #"Changed Type";

// Data Source Kind description
YoutubeAnalytics = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

// Data Source UI publishing description
YoutubeAnalytics.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = YoutubeAnalytics.Icons,
    SourceTypeImage = YoutubeAnalytics.Icons
];

///// Youtube Official Branding https://www.youtube.com/yt/brand/downloads.html all rights reserved 

YoutubeAnalytics.Icons = [
    Icon16 = { Extension.Contents("YoutubeAnalytics16.png"), Extension.Contents("YoutubeAnalytics20.png"), Extension.Contents("YoutubeAnalytics24.png"), Extension.Contents("YoutubeAnalytics32.png") },
    Icon32 = { Extension.Contents("YoutubeAnalytics32.png"), Extension.Contents("YoutubeAnalytics40.png"), Extension.Contents("YoutubeAnalytics48.png"), Extension.Contents("YoutubeAnalytics64.png") }
];

StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
        client_id = appKey,  
        redirect_uri = redirectUrl,   
        state="security_token",
        scope = GetScopeString(scopes, scope_prefix),
        response_type = "code",
        response_mode = "query",
        access_type="offline",
        login = "login"    
    ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirectUrl,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                   TokenMethod(parts[code])
    in
        result;


TokenMethod = (code) =>
    let
        response = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString([
                grant_type = "authorization_code",
                client_id = appKey,
                client_secret = appSecret,
                code = code,
                redirect_uri = redirectUrl])),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"], ManualStatusHandling = {400}]),
        body = Json.Document(response),
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body)
                 else
                    body
    in
        result;

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;

