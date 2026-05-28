package id.rahmat.taniin;

import android.content.Context;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.RectF;

import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import javax.xml.parsers.DocumentBuilderFactory;

final class TmxMap {
    private static final long FLIP_MASK = 0xE0000000L;
    private static final long GID_MASK = ~FLIP_MASK;

    private final List<Tileset> tilesets = new ArrayList<>();
    private final List<MapLayer> layers = new ArrayList<>();
    private final Paint pixelPaint = new Paint();
    private final Paint miniPaint = new Paint();
    private final Rect src = new Rect();
    private final RectF dst = new RectF();

    private int tileWidth = 16;
    private int tileHeight = 16;
    private int minTileX;
    private int minTileY;
    private int maxTileX;
    private int maxTileY;

    private TmxMap() {
        pixelPaint.setAntiAlias(false);
        pixelPaint.setFilterBitmap(false);
        miniPaint.setAntiAlias(false);
        miniPaint.setStyle(Paint.Style.FILL);
    }

    static TmxMap load(Context context, String assetPath) throws Exception {
        TmxMap map = new TmxMap();
        AssetManager assets = context.getAssets();
        String basePath = parentPath(assetPath);

        Document document = parse(assets, assetPath);
        Element mapElement = document.getDocumentElement();
        map.tileWidth = intAttr(mapElement, "tilewidth", 16);
        map.tileHeight = intAttr(mapElement, "tileheight", 16);

        NodeList tilesetNodes = mapElement.getElementsByTagName("tileset");
        for (int i = 0; i < tilesetNodes.getLength(); i++) {
            Element element = (Element) tilesetNodes.item(i);
            String source = element.getAttribute("source");
            if (source.isEmpty()) {
                continue;
            }
            int firstGid = intAttr(element, "firstgid", 1);
            map.tilesets.add(loadTileset(assets, basePath, source, firstGid));
        }
        map.tilesets.sort(Comparator.comparingInt(t -> t.firstGid));

        int minX = Integer.MAX_VALUE;
        int minY = Integer.MAX_VALUE;
        int maxX = Integer.MIN_VALUE;
        int maxY = Integer.MIN_VALUE;

        NodeList children = mapElement.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node node = children.item(i);
            if (!(node instanceof Element) || !"layer".equals(node.getNodeName())) {
                continue;
            }
            Element layerElement = (Element) node;
            MapLayer layer = new MapLayer(layerElement.getAttribute("name"));
            NodeList chunks = layerElement.getElementsByTagName("chunk");
            for (int c = 0; c < chunks.getLength(); c++) {
                Element chunk = (Element) chunks.item(c);
                int chunkX = intAttr(chunk, "x", 0);
                int chunkY = intAttr(chunk, "y", 0);
                int chunkWidth = intAttr(chunk, "width", 0);
                String[] values = chunk.getTextContent().split(",");
                int valueIndex = 0;
                for (String rawValue : values) {
                    String trimmed = rawValue.trim();
                    if (trimmed.isEmpty()) {
                        continue;
                    }
                    long rawGid = Long.parseLong(trimmed);
                    int gid = (int) (rawGid & GID_MASK);
                    int localX = valueIndex % chunkWidth;
                    int localY = valueIndex / chunkWidth;
                    valueIndex++;
                    if (gid == 0) {
                        continue;
                    }
                    int tileX = chunkX + localX;
                    int tileY = chunkY + localY;
                    layer.tiles.add(new Tile(tileX, tileY, gid));
                    minX = Math.min(minX, tileX);
                    minY = Math.min(minY, tileY);
                    maxX = Math.max(maxX, tileX);
                    maxY = Math.max(maxY, tileY);
                }
            }
            if (!layer.tiles.isEmpty()) {
                map.layers.add(layer);
            }
        }

        if (minX == Integer.MAX_VALUE) {
            minX = 0;
            minY = 0;
            maxX = 1;
            maxY = 1;
        }
        map.minTileX = minX;
        map.minTileY = minY;
        map.maxTileX = maxX;
        map.maxTileY = maxY;
        return map;
    }

    int getWorldWidthPixels(int targetTileSize) {
        return (maxTileX - minTileX + 1) * targetTileSize;
    }

    int getWorldHeightPixels(int targetTileSize) {
        return (maxTileY - minTileY + 1) * targetTileSize;
    }

    void appendCollisionRects(List<RectF> rects, int targetTileSize) {
        Set<Long> bridgeTiles = new HashSet<>();
        for (MapLayer layer : layers) {
            for (Tile tile : layer.tiles) {
                if (isBridgeTile(tile.gid)) {
                    bridgeTiles.add(tileKey(tile.x, tile.y));
                }
            }
        }

        for (MapLayer layer : layers) {
            for (Tile tile : layer.tiles) {
                long key = tileKey(tile.x, tile.y);
                if (bridgeTiles.contains(key) && isWaterTile(tile.gid)) {
                    continue;
                }
                float left = (tile.x - minTileX) * targetTileSize;
                float top = (tile.y - minTileY) * targetTileSize;
                appendCollisionRect(rects, layer.name, tile.gid, left, top, targetTileSize);
            }
        }
    }

    void draw(Canvas canvas, float cameraX, float cameraY, int targetTileSize) {
        drawLayers(canvas, cameraX, cameraY, targetTileSize, false);
        drawLayers(canvas, cameraX, cameraY, targetTileSize, true);
    }

    void drawBackground(Canvas canvas, float cameraX, float cameraY, int targetTileSize) {
        drawLayers(canvas, cameraX, cameraY, targetTileSize, false);
    }

    void drawForeground(Canvas canvas, float cameraX, float cameraY, int targetTileSize) {
        drawLayers(canvas, cameraX, cameraY, targetTileSize, true);
    }

    void drawMiniMap(Canvas canvas, RectF bounds, int targetTileSize) {
        float scaleX = bounds.width() / Math.max(1, getWorldWidthPixels(targetTileSize));
        float scaleY = bounds.height() / Math.max(1, getWorldHeightPixels(targetTileSize));
        float tileW = Math.max(1f, targetTileSize * scaleX);
        float tileH = Math.max(1f, targetTileSize * scaleY);

        miniPaint.setColor(Color.rgb(105, 184, 78));
        canvas.drawRect(bounds, miniPaint);

        for (MapLayer layer : layers) {
            for (Tile tile : layer.tiles) {
                Tileset tileset = findTileset(tile.gid);
                if (tileset == null || tileset.bitmap == null) {
                    continue;
                }
                int localId = tile.gid - tileset.firstGid;
                int sourceX = (localId % tileset.columns) * tileset.tileWidth;
                int sourceY = (localId / tileset.columns) * tileset.tileHeight;
                src.set(sourceX, sourceY, sourceX + tileset.tileWidth, sourceY + tileset.tileHeight);
                float x = bounds.left + (tile.x - minTileX) * targetTileSize * scaleX;
                float y = bounds.top + (tile.y - minTileY) * targetTileSize * scaleY;
                dst.set(x, y, x + tileW, y + tileH);
                canvas.drawBitmap(tileset.bitmap, src, dst, pixelPaint);
            }
        }
    }

    private void drawLayers(
            Canvas canvas,
            float cameraX,
            float cameraY,
            int targetTileSize,
            boolean foreground) {
        float scale = targetTileSize / (float) tileWidth;
        int firstTileX = Math.max(minTileX, minTileX + (int) (cameraX / targetTileSize) - 2);
        int firstTileY = Math.max(minTileY, minTileY + (int) (cameraY / targetTileSize) - 2);
        int lastTileX = Math.min(maxTileX, minTileX + (int) ((cameraX + canvas.getWidth()) / targetTileSize) + 3);
        int lastTileY = Math.min(maxTileY, minTileY + (int) ((cameraY + canvas.getHeight()) / targetTileSize) + 3);

        for (MapLayer layer : layers) {
            for (Tile tile : layer.tiles) {
                if (isDrawnInForeground(layer.name, tile.gid) != foreground) {
                    continue;
                }
                if (tile.x < firstTileX || tile.x > lastTileX || tile.y < firstTileY || tile.y > lastTileY) {
                    continue;
                }
                Tileset tileset = findTileset(tile.gid);
                if (tileset == null || tileset.bitmap == null) {
                    continue;
                }
                int localId = tile.gid - tileset.firstGid;
                int sourceX = (localId % tileset.columns) * tileset.tileWidth;
                int sourceY = (localId / tileset.columns) * tileset.tileHeight;
                src.set(sourceX, sourceY, sourceX + tileset.tileWidth, sourceY + tileset.tileHeight);
                float screenX = (tile.x - minTileX) * targetTileSize - cameraX;
                float screenY = (tile.y - minTileY) * targetTileSize - cameraY;
                dst.set(
                        screenX,
                        screenY,
                        screenX + tileset.tileWidth * scale,
                        screenY + tileset.tileHeight * scale);
                canvas.drawBitmap(tileset.bitmap, src, dst, pixelPaint);
            }
        }
    }

    private Tileset findTileset(int gid) {
        Tileset result = null;
        for (Tileset tileset : tilesets) {
            if (gid >= tileset.firstGid) {
                result = tileset;
            } else {
                break;
            }
        }
        return result;
    }

    private static void appendCollisionRect(
            List<RectF> rects,
            String layerName,
            int gid,
            float left,
            float top,
            int size) {
        if (isBridgeTile(gid)) {
            return;
        }
        if (isWaterTile(gid)) {
            rects.add(new RectF(left, top, left + size, top + size));
            return;
        }
        if ("Tile Layer 1".equals(layerName)) {
            return;
        }
        if (isHouseTile(gid) || isFenceTile(gid)) {
            rects.add(new RectF(left, top, left + size, top + size));
            return;
        }
        if (isMapleTreeFootTile(gid) || isWoodTreeFootTile(gid)) {
            addInsetRect(rects, left, top, size, 0.18f, 0.38f, 0.82f, 0.95f);
            return;
        }
        if (isLampTile(gid)) {
            appendLampCollision(rects, gid, left, top, size);
            return;
        }
        if (isSmallObstacleTile(gid)) {
            addInsetRect(rects, left, top, size, 0.14f, 0.18f, 0.86f, 0.94f);
        }
    }

    private static void addInsetRect(
            List<RectF> rects,
            float left,
            float top,
            int size,
            float leftInset,
            float topInset,
            float rightInset,
            float bottomInset) {
        rects.add(new RectF(
                left + size * leftInset,
                top + size * topInset,
                left + size * rightInset,
                top + size * bottomInset));
    }

    private static void appendLampCollision(List<RectF> rects, int gid, float left, float top, int size) {
        if (gid == 624) {
            return;
        }
        if (gid == 631) {
            return;
        }
        addInsetRect(rects, left, top, size, 0.40f, 0.66f, 0.60f, 0.92f);
    }

    private static boolean isWaterTile(int gid) {
        switch (gid) {
            case 818:
            case 819:
            case 821:
            case 840:
            case 861:
            case 865:
            case 883:
            case 884:
            case 906:
            case 907:
                return true;
            default:
                return false;
        }
    }

    private static boolean isBridgeTile(int gid) {
        return gid >= 1396 && gid <= 1410;
    }

    private static boolean isHouseTile(int gid) {
        return (gid >= 241 && gid < 339) || gid >= 1431;
    }

    private static boolean isFenceTile(int gid) {
        return gid >= 369 && gid < 384;
    }

    private static boolean isMapleTreeFootTile(int gid) {
        return gid >= 363 && gid <= 368;
    }

    private static boolean isMapleTreeTile(int gid) {
        return gid >= 339 && gid < 369;
    }

    private static boolean isWoodTreeTile(int gid) {
        if (gid >= 1411 && gid <= 1430) {
            return true;
        }
        if (gid >= 693 && gid <= 696) {
            return true;
        }
        if (gid >= 715 && gid <= 718) {
            return true;
        }
        if (gid >= 737 && gid <= 740) {
            return true;
        }
        if (gid >= 759 && gid <= 762) {
            return true;
        }
        if (gid >= 781 && gid <= 784) {
            return true;
        }
        switch (gid) {
            case 803:
            case 804:
            case 825:
            case 826:
            case 827:
            case 828:
            case 847:
            case 848:
            case 849:
            case 850:
                return true;
            default:
                return false;
        }
    }

    private static boolean isWoodTreeFootTile(int gid) {
        if (gid >= 1427 && gid <= 1430) {
            return true;
        }
        switch (gid) {
            case 781:
            case 782:
            case 783:
            case 784:
            case 847:
            case 848:
            case 849:
            case 850:
                return true;
            default:
                return false;
        }
    }

    private static boolean isLampTile(int gid) {
        return gid == 624 || gid == 631 || gid == 638;
    }

    private static boolean isSmallObstacleTile(int gid) {
        switch (gid) {
            case 606:
            case 607:
            case 608:
            case 643:
            case 800:
            case 801:
            case 823:
            case 827:
            case 828:
            case 866:
            case 867:
            case 887:
                return true;
            default:
                return false;
        }
    }

    private static boolean isForegroundLayer(String layerName) {
        return layerName != null && layerName.toLowerCase(Locale.US).contains("depan");
    }

    private static boolean isDrawnInForeground(String layerName, int gid) {
        return isLampTile(gid)
                || isMapleTreeTile(gid)
                || isWoodTreeTile(gid)
                || isSmallObstacleTile(gid)
                || (isForegroundLayer(layerName)
                && gid >= 241
                && !isWaterTile(gid));
    }

    private static long tileKey(int x, int y) {
        return ((long) x << 32) ^ (y & 0xffffffffL);
    }

    private static Tileset loadTileset(
            AssetManager assets,
            String mapBasePath,
            String tilesetSource,
            int firstGid) throws Exception {
        String tilesetPath = joinAssetPath(mapBasePath, tilesetSource);
        Document document = parse(assets, tilesetPath);
        Element tilesetElement = document.getDocumentElement();
        Element imageElement = firstElement(tilesetElement, "image");
        String imageSource = imageElement.getAttribute("source");
        String imagePath = joinAssetPath(parentPath(tilesetPath), imageSource);

        Bitmap bitmap;
        try (InputStream inputStream = assets.open(imagePath)) {
            bitmap = BitmapFactory.decodeStream(inputStream);
        }

        return new Tileset(
                firstGid,
                intAttr(tilesetElement, "tilewidth", 16),
                intAttr(tilesetElement, "tileheight", 16),
                intAttr(tilesetElement, "columns", 1),
                bitmap);
    }

    private static Document parse(AssetManager assets, String assetPath) throws Exception {
        try (InputStream inputStream = assets.open(assetPath)) {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setIgnoringComments(true);
            factory.setCoalescing(true);
            return factory.newDocumentBuilder().parse(inputStream);
        }
    }

    private static Element firstElement(Element parent, String tagName) {
        NodeList list = parent.getElementsByTagName(tagName);
        return (Element) list.item(0);
    }

    private static int intAttr(Element element, String name, int fallback) {
        String value = element.getAttribute(name);
        if (value == null || value.isEmpty()) {
            return fallback;
        }
        return Integer.parseInt(value);
    }

    private static String parentPath(String path) {
        int slash = path.lastIndexOf('/');
        return slash < 0 ? "" : path.substring(0, slash);
    }

    private static String joinAssetPath(String parent, String child) {
        if (parent == null || parent.isEmpty()) {
            return child;
        }
        return parent + "/" + child;
    }

    private static final class Tileset {
        final int firstGid;
        final int tileWidth;
        final int tileHeight;
        final int columns;
        final Bitmap bitmap;

        Tileset(int firstGid, int tileWidth, int tileHeight, int columns, Bitmap bitmap) {
            this.firstGid = firstGid;
            this.tileWidth = tileWidth;
            this.tileHeight = tileHeight;
            this.columns = Math.max(1, columns);
            this.bitmap = bitmap;
        }
    }

    private static final class MapLayer {
        final String name;
        final List<Tile> tiles = new ArrayList<>();

        MapLayer(String name) {
            this.name = name;
        }
    }

    private static final class Tile {
        final int x;
        final int y;
        final int gid;

        Tile(int x, int y, int gid) {
            this.x = x;
            this.y = y;
            this.gid = gid;
        }
    }
}
