/*
 This file is part of Subsonic.

 Subsonic is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Subsonic is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Subsonic.  If not, see <http://www.gnu.org/licenses/>.

 Copyright 2009 (C) Sindre Mehus
 */
package net.sourceforge.subsonic.ajax;

import net.sourceforge.subsonic.Logger;
import net.sourceforge.subsonic.domain.MediaFile;
import net.sourceforge.subsonic.service.MediaFileService;
import net.sourceforge.subsonic.service.metadata.MetaData;
import net.sourceforge.subsonic.service.metadata.MetaDataParser;
import net.sourceforge.subsonic.service.metadata.MetaDataParserFactory;
import net.sourceforge.subsonic.util.StringUtil;
import org.apache.commons.lang.ObjectUtils;
import org.apache.commons.lang.StringUtils;

/**
 * Provides AJAX-enabled services for editing tags in music files.
 * This class is used by the DWR framework (http://getahead.ltd.uk/dwr/).
 *
 * @author Sindre Mehus
 */
public class TagService {

    private static final Logger LOG = Logger.getLogger(TagService.class);

    private MetaDataParserFactory metaDataParserFactory;
    private MediaFileService mediaFileService;

    /**
     * Updated tags for a given music file.
     *
     * @param path   The path of the music file.
     * @param track  The track number.
     * @param artist The artist name.
     * @param album  The album name.
     * @param title  The song title.
     * @param year   The release year.
     * @param genre  The musical genre.
     * @return "UPDATED" if the new tags were updated, "SKIPPED" if no update was necessary.
     *         Otherwise the error message is returned.
     */
    public String setTags(String path, String track, String artist, String album, String title, String year, String genre) {

        track = StringUtils.trimToNull(track);
        artist = StringUtils.trimToNull(artist);
        album = StringUtils.trimToNull(album);
        title = StringUtils.trimToNull(title);
        year = StringUtils.trimToNull(year);
        genre = StringUtils.trimToNull(genre);

        Integer trackNumber = null;
        if (track != null) {
            try {
                trackNumber = new Integer(track);
            } catch (NumberFormatException x) {
                LOG.warn("Illegal track number: " + track, x);
            }
        }

        Integer yearNumber = null;
        if (year != null) {
            try {
                yearNumber = new Integer(year);
            } catch (NumberFormatException x) {
                LOG.warn("Illegal year: " + year, x);
            }
        }

        try {

            MediaFile file = mediaFileService.getMediaFile(path);
            MetaDataParser parser = metaDataParserFactory.getParser(file);

            if (!parser.isEditingSupported()) {
                return "Tag editing of " + StringUtil.getSuffix(file.getName()) + " files is not supported.";
            }

            MetaData existingMetaData = parser.getRawMetaData(file);

            if (StringUtils.equals(artist, existingMetaData.getArtist()) &&
                    StringUtils.equals(album, existingMetaData.getAlbumName()) &&
                    StringUtils.equals(title, existingMetaData.getTitle()) &&
                    ObjectUtils.equals(yearNumber, existingMetaData.getYear()) &&
                    StringUtils.equals(genre, existingMetaData.getGenre()) &&
                    ObjectUtils.equals(trackNumber, existingMetaData.getTrackNumber())) {
                return "SKIPPED";
            }

            MetaData newMetaData = new MetaData();
            newMetaData.setArtist(artist);
            newMetaData.setAlbumName(album);
            newMetaData.setTitle(title);
            newMetaData.setYear(yearNumber);
            newMetaData.setGenre(genre);
            newMetaData.setTrackNumber(trackNumber);
            parser.setMetaData(file, newMetaData);
            return "UPDATED";

        } catch (Exception x) {
            LOG.warn("Failed to update tags for " + path, x);
            return x.getMessage();
        }
    }

    public void setMediaFileService(MediaFileService mediaFileService) {
        this.mediaFileService = mediaFileService;
    }

    public void setMetaDataParserFactory(MetaDataParserFactory metaDataParserFactory) {
        this.metaDataParserFactory = metaDataParserFactory;
    }
}
