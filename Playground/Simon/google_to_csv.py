# convert google to .csv file

import os
import numpy as np
import pandas as pd

def load_exp_table(sheet_names, sheet_id="1aOrgfBghYhOMhVDdm5tUUqLT4ibVo1oFhVtgjkOMo4s"):
    """loads the experiment table containing data about all experiments 

    Args:
        sheet_names (list): list of sheet names (mice) to load
        sheet_id (str, optional): identifier for the google sheet if chosen. Defaults to "1aOrgfBghYhOMhVDdm5tUUqLT4ibVo1oFhVtgjkOMo4s".

    Returns:
        exp_table (pd.DataFrame): dataframe containing experimental sessions choosen 
    """    
    exp_table = []
    for sheet in sheet_names:
        url = f"https://docs.google.com/spreadsheets/d/{sheet_id}/gviz/tq?tqx=out:csv&sheet={sheet}"
        try:
            cur_df = pd.read_csv(url, dtype={'Animal ID' : str})
            if len(exp_table) == 0:
                exp_table = cur_df
            else:
                exp_table = pd.concat([exp_table, cur_df])
        except:
            print(sheet + ' not in goole sheet')
            continue

    stripped_columns = [x.strip() for x in exp_table.columns]
    exp_table.columns = stripped_columns
        
    return exp_table


def convert_google_to_tsv(
    sheet_names=['2802', '2805', '2842', '2858', '2860', '2904', '2905', '2906'],
    savefolder=r'X:\temp_dendrites\neuroblueprint_test\MEAT_2p'):

    table = load_exp_table(sheet_names, sheet_id="1aOrgfBghYhOMhVDdm5tUUqLT4ibVo1oFhVtgjkOMo4s")

    table = table.rename(mapper={'Animal ID' : 'mouse', 
                         'Date' : 'date', 
                         'Area' : 'area'},
                         axis='columns')

    table['Focus'] = table['Focus'].str.rstrip()
    table['Comments after manual curation'] = table['Comments after manual curation'].str.rstrip()

    tsv_table = []
    tsv_header = [
        'mouse', 
        'date', 
        'time', 
        'area', 
        'depth', 
        'path', 
        'plane_1',
        'man_curation_plane_1', 
        'plane_2', 
        'man_curation_plane_2',
        'rating_behavior', 
        'rating_recording',
        'recording_type']

    # go through mouse, date and area to reassamble entries for each session in new format
    for m, mouse in enumerate(table.mouse.unique()):
        for d, date in enumerate(table[table.mouse == mouse].date.unique()):
            for area in table[(table.mouse == mouse) & (table.date == date)].area.unique():
                try:
                    # create new line for specific experimente splitting comments about soma and dendrites into specific columns
                    # and creating new naming scheme for the path
                    cur_exp = table[(table.mouse == mouse) & (table.date == date) & (table.area == area)]
                    cur_id = cur_exp.iloc[0].mouse
                    cur_date = str(int(cur_exp.iloc[0].date))
                    cur_area = area
                    # get current tiff file to acquire time and depth
                    tif_path = cur_exp.iloc[0].Path
                    tif_name = [x for x in os.listdir(tif_path) if '.tif' in x and 'stack' not in x][0]
                    tif_comps = tif_name.split('.')[0].split('_')
                    # get depth from tif comps

                    # try to find depth by um
                    um_depth = [x for x in tif_comps if 'um' in x]
                    if len(um_depth) == 0:
                        # try to find depth by position
                        pos_ind = np.where(np.array(tif_comps) == area)[0]
                        if len(pos_ind) == 0:
                            cur_depth = np.nan
                        else:
                            if tif_comps[pos_ind[0]+1].isnumeric():
                                cur_depth = tif_comps[pos_ind[0]+1]
                            else:
                                cur_depth = np.nan
                    else:
                        cur_depth = um_depth[0].split('um')[0]


                    # cur_depth = tif_comps[np.where(np.array(tif_comps) == area)[0][0]+1].split('um')[0]
                    # get time from tif comps
                    cur_time = tif_comps[np.where(np.array(tif_comps) == cur_date)[0][0]+1]
                    # get relative path from tif comps
                    cur_path = os.path.join(
                        'rawdata',
                        'sub-'+str(m+1).zfill(3)+'_'+'id-'+cur_id,
                        'ses-'+str(d+1).zfill(3)+'_'+'datetime-'+str(cur_date)+'T'+str(cur_time),
                        'funcimg'
                    )
                    # distribute comments into seperate columns
                    if cur_exp.iloc[0].Planes.lower() == '2 planes':
                        cur_plane_1 = 'dendrites'
                        cur_plane_2 = 'soma'
                        cur_comm_plane_1 = cur_exp[cur_exp.Focus == 'dendrites']['Comments after manual curation'].iloc[0]
                        cur_comm_plane_2 = cur_exp[cur_exp.Focus == 'soma']['Comments after manual curation'].iloc[0]

                    elif cur_exp.iloc[0].Planes.lower() == '1 plane':
                        cur_plane_1 = cur_exp.iloc[0].Focus
                        cur_plane_2 = np.nan
                        cur_comm_plane_1 = cur_exp.iloc[0]['Comments after manual curation']
                        cur_comm_plane_2 = np.nan

                    cur_rating_behavior = cur_exp.iloc[0]['Behavior']
                    cur_rating_recording = cur_exp.iloc[0]['Recording']
                    cur_recording_type = cur_exp.iloc[0]['Session'].lower()

                    tsv_table.append([
                        cur_id, 
                        cur_date, 
                        cur_time, 
                        cur_area, 
                        cur_depth, 
                        cur_path, 
                        cur_plane_1, 
                        cur_comm_plane_1, 
                        cur_plane_2, 
                        cur_comm_plane_2,
                        cur_rating_behavior,
                        cur_rating_recording,
                        cur_recording_type
                        ])
                except:
                    print('_'.join([str(mouse), str(date), str(area)]) + ' did not work')


    tsv_df = pd.DataFrame(data=tsv_table, columns=tsv_header)
    tsv_df = tsv_df.fillna(value='n/a')
    tsv_df.to_csv(os.path.join(savefolder, 'metadata.tsv'), sep='\t', encoding='utf-8')